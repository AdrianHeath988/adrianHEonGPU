#include "plaintext_c_api.h"
#include "heongpu.cuh"
#include "ckks/context.cuh"
#include "ckks/plaintext.cuh"
#include "util/hostvector.cuh"
#include "util/schemes.h"      // For heongpu::scheme_type, heongpu::Data64
#include "util/storagemanager.cuh" // For heongpu::storage_type, heongpu::ExecutionOptions

#include <vector>
#include <sstream>
#include <iostream>
#include <algorithm> // For std::min
#include <cstring>   // For std::memcpy
#include <new>       // For std::nothrow


typedef struct HE_CKKS_Plaintext_s HE_CKKS_Plaintext;

// Helper to safely access the underlying C++ HEContext pointer
static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context(HE_CKKS_Context* context) {
    if (!context || !context->cpp_context) {
        std::cerr << "Error: Invalid HE_CKKS_Context pointer provided." << std::endl;
        return nullptr;
    }
    return context->cpp_context; // cpp_context is the member name
}

// Helper to map C types to C++ ExecutionOptions
static heongpu::ExecutionOptions map_c_to_cpp_execution_options(const C_ExecutionOptions* c_options) {
    heongpu::ExecutionOptions cpp_options;
    if (c_options) {
        cpp_options.stream_ = static_cast<cudaStream_t>(c_options->stream);
        if (c_options->storage == C_STORAGE_TYPE_HOST) {
            cpp_options.storage_ = heongpu::storage_type::HOST;
        } else { // Default to DEVICE if C_STORAGE_TYPE_DEVICE or invalid
            cpp_options.storage_ = heongpu::storage_type::DEVICE;
        }
        cpp_options.keep_initial_condition_ = c_options->keep_initial_condition;
    }
    // If c_options is null, cpp_options uses its default members (cudaStreamDefault, DEVICE, true)
    return cpp_options;
}

// Helper to map C++ scheme_type to C_scheme_type
static C_scheme_type map_cpp_to_c_scheme_type(heongpu::scheme_type cpp_type) {
    switch (cpp_type) {
        case heongpu::scheme_type::none: return C_SCHEME_TYPE_NONE;
        case heongpu::scheme_type::bfv:  return C_SCHEME_TYPE_BFV;
        case heongpu::scheme_type::ckks: return C_SCHEME_TYPE_CKKS;
        case heongpu::scheme_type::bgv:  return C_SCHEME_TYPE_BGV;
        default: return static_cast<C_scheme_type>(-1); // Error/Unknown
    }
}

// Helper to map C++ storage_type to C_storage_type
static C_storage_type map_cpp_to_c_storage_type(heongpu::storage_type cpp_type) {
    switch (cpp_type) {
        case heongpu::storage_type::HOST:   return C_STORAGE_TYPE_HOST;
        case heongpu::storage_type::DEVICE: return C_STORAGE_TYPE_DEVICE;
        default: return C_STORAGE_TYPE_INVALID;
    }
}


extern "C" {

// --- Lifecycle & Serialization ---

HE_CKKS_Plaintext* HEonGPU_CKKS_Plaintext_Create(HE_CKKS_Context* context,
                                                 const C_ExecutionOptions* options) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Create failed: HE_CKKS_Context is null or invalid." << std::endl;
        return nullptr;
    }
    try {
        heongpu::ExecutionOptions cpp_exec_options = map_c_to_cpp_execution_options(options);
        heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_pt =
            new (std::nothrow) heongpu::Plaintext<heongpu::Scheme::CKKS>(*cpp_h_context, cpp_exec_options);
        if (!cpp_pt) {
            std::cerr << "HEonGPU_CKKS_Plaintext_Create failed: C++ Plaintext allocation failed." << std::endl;
            return nullptr;
        }
        HE_CKKS_Plaintext* c_api_plaintext = new (std::nothrow) HE_CKKS_Plaintext_s;
        if (!c_api_plaintext) {
            std::cerr << "HEonGPU_CKKS_Plaintext_Create failed: C API Plaintext wrapper allocation failed." << std::endl;
            delete cpp_pt;
            return nullptr;
        }
        c_api_plaintext->cpp_plaintext = cpp_pt;
        return c_api_plaintext;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Create failed with C++ exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Create failed due to an unknown C++ exception." << std::endl;
        return nullptr;
    }
}

void HEonGPU_CKKS_Plaintext_Delete(HE_CKKS_Plaintext* plaintext) {
    if (plaintext) {
        delete plaintext->cpp_plaintext;
        delete plaintext;
    }
}

HE_CKKS_Plaintext* HEonGPU_CKKS_Plaintext_Clone(const HE_CKKS_Plaintext* other_plaintext) {
    if (!other_plaintext || !other_plaintext->cpp_plaintext) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Clone failed: Invalid source plaintext pointer." << std::endl;
        return nullptr;
    }
    try {
        heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_cloned_pt =
            new (std::nothrow) heongpu::Plaintext<heongpu::Scheme::CKKS>(*(other_plaintext->cpp_plaintext));
        if(!cpp_cloned_pt) {
            std::cerr << "HEonGPU_CKKS_Plaintext_Clone failed: C++ Plaintext (clone) allocation failed." << std::endl;
            return nullptr;
        }
        HE_CKKS_Plaintext* c_api_cloned_plaintext = new (std::nothrow) HE_CKKS_Plaintext_s;
        if (!c_api_cloned_plaintext) {
            std::cerr << "HEonGPU_CKKS_Plaintext_Clone failed: C API Plaintext wrapper (clone) allocation failed." << std::endl;
            delete cpp_cloned_pt;
            return nullptr;
        }
        c_api_cloned_plaintext->cpp_plaintext = cpp_cloned_pt;
        return c_api_cloned_plaintext;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Clone failed with C++ exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Clone failed due to an unknown C++ exception." << std::endl;
        return nullptr;
    }
}

int HEonGPU_CKKS_Plaintext_Assign_Copy(HE_CKKS_Plaintext* dest_plaintext,
                                       const HE_CKKS_Plaintext* src_plaintext) {
    if (!dest_plaintext || !dest_plaintext->cpp_plaintext ||
        !src_plaintext || !src_plaintext->cpp_plaintext) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Assign_Copy failed: Invalid destination or source plaintext pointer." << std::endl;
        return -1; 
    }
    try {
        *(dest_plaintext->cpp_plaintext) = *(src_plaintext->cpp_plaintext);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Assign_Copy failed with C++ exception: " << e.what() << std::endl;
        return -2;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Assign_Copy failed due to an unknown C++ exception." << std::endl;
        return -2;
    }
}

int HEonGPU_CKKS_Plaintext_Save(HE_CKKS_Plaintext* plaintext,
                                unsigned char** out_bytes,
                                size_t* out_len) {
    if (!plaintext || !plaintext->cpp_plaintext || !out_bytes || !out_len) {
        if(out_bytes) *out_bytes = nullptr;
        if(out_len) *out_len = 0;
        return -1; 
    }
    *out_bytes = nullptr;
    *out_len = 0;
    try {
        std::ostringstream oss(std::ios::binary);
        plaintext->cpp_plaintext->save(oss);
        std::string str_data = oss.str();
        *out_len = str_data.length();
        if (*out_len == 0) {
            *out_bytes = nullptr; 
            return 0;
        }
        *out_bytes = static_cast<unsigned char*>(malloc(*out_len)); 
        if (!(*out_bytes)) {
            *out_len = 0;
            std::cerr << "HEonGPU_CKKS_Plaintext_Save failed: Memory allocation error." << std::endl;
            return -2;
        }
        std::memcpy(*out_bytes, str_data.data(), *out_len);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Save failed with C++ exception: " << e.what() << std::endl;
        if (*out_bytes) { free(*out_bytes); *out_bytes = nullptr; }
        *out_len = 0;
        return -3;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Save failed due to an unknown C++ exception." << std::endl;
        if (*out_bytes) { free(*out_bytes); *out_bytes = nullptr; }
        *out_len = 0;
        return -3;
    }
}

HE_CKKS_Plaintext* HEonGPU_CKKS_Plaintext_Load(HE_CKKS_Context* context,
                                               const unsigned char* bytes,
                                               size_t len,
                                               const C_ExecutionOptions* options) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Load failed: HE_CKKS_Context is null or invalid." << std::endl;
        return nullptr;
    }
    if (!bytes && len > 0) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Load failed: Invalid bytes pointer for non-zero length." << std::endl;
        return nullptr;
    }

    HE_CKKS_Plaintext* c_api_plaintext = nullptr;
    heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_pt = nullptr;
    try {
        heongpu::ExecutionOptions cpp_exec_options = map_c_to_cpp_execution_options(options);
        // First, create a Plaintext object using the constructor that takes ExecutionOptions
        cpp_pt = new (std::nothrow) heongpu::Plaintext<heongpu::Scheme::CKKS>(*cpp_h_context, cpp_exec_options);
        if (!cpp_pt) {
            std::cerr << "HEonGPU_CKKS_Plaintext_Load failed: C++ Plaintext allocation failed." << std::endl;
            return nullptr;
        }

        if (len > 0 && bytes) { // Only load if there's data
            std::string str_data(reinterpret_cast<const char*>(bytes), len);
            std::istringstream iss(str_data, std::ios::binary);
            cpp_pt->load(iss);
        }
        // If len is 0, cpp_pt is a newly constructed plaintext with default options.

        c_api_plaintext = new (std::nothrow) HE_CKKS_Plaintext_s;
        if (!c_api_plaintext) {
            std::cerr << "HEonGPU_CKKS_Plaintext_Load failed: C API Plaintext wrapper allocation failed." << std::endl;
            delete cpp_pt;
            return nullptr;
        }
        c_api_plaintext->cpp_plaintext = cpp_pt;
        return c_api_plaintext;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Load failed with C++ exception: " << e.what() << std::endl;
        delete cpp_pt;
        delete c_api_plaintext;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Plaintext_Load failed due to an unknown C++ exception." << std::endl;
        delete cpp_pt;
        delete c_api_plaintext;
        return nullptr;
    }
}


// --- CKKS Plaintext Getters ---

C_scheme_type HEonGPU_CKKS_Plaintext_GetScheme(HE_CKKS_Plaintext* plaintext) {
    if (!plaintext || !plaintext->cpp_plaintext) {
        std::cerr << "Error: Invalid plaintext pointer in GetScheme." << std::endl;
        return static_cast<C_scheme_type>(-1); // Error
    }
    try {
        return map_cpp_to_c_scheme_type(plaintext->cpp_plaintext->get_scheme());
    } catch (...) { return static_cast<C_scheme_type>(-1); }
}

int HEonGPU_CKKS_Plaintext_GetPlainSize(HE_CKKS_Plaintext* plaintext) {
    if (!plaintext || !plaintext->cpp_plaintext) {
        std::cerr << "Error: Invalid plaintext pointer in GetPlainSize." << std::endl;
        return 0;
    }
    try {
        return plaintext->cpp_plaintext->plain_size();
    } catch (...) { return 0; }
}

int HEonGPU_CKKS_Plaintext_GetDepth(HE_CKKS_Plaintext* plaintext) {
    if (!plaintext || !plaintext->cpp_plaintext) {
        std::cerr << "Error: Invalid plaintext pointer in GetDepth." << std::endl;
        return 0; // Or an error indicator like -1 if 0 can be a valid depth
    }
    try {
        return plaintext->cpp_plaintext->depth();
    } catch (...) { return 0; }
}

double HEonGPU_CKKS_Plaintext_GetScale(HE_CKKS_Plaintext* plaintext) {
    if (!plaintext || !plaintext->cpp_plaintext) {
        std::cerr << "Error: Invalid plaintext pointer in GetScale." << std::endl;
        return -1.0; // Error indicator
    }
    try {
        return plaintext->cpp_plaintext->get_scale();
    } catch (...) { return -1.0; }
}

bool HEonGPU_CKKS_Plaintext_IsInNttDomain(HE_CKKS_Plaintext* plaintext) {
    if (!plaintext || !plaintext->cpp_plaintext) {
        std::cerr << "Error: Invalid plaintext pointer in IsInNttDomain." << std::endl;
        return false;
    }
    try {
        return plaintext->cpp_plaintext->is_in_ntt_domain();
    } catch (...) { return false; }
}

C_storage_type HEonGPU_CKKS_Plaintext_GetStorageType(HE_CKKS_Plaintext* plaintext) {
    if (!plaintext || !plaintext->cpp_plaintext) {
        std::cerr << "Error: Invalid plaintext pointer in GetStorageType." << std::endl;
        return C_STORAGE_TYPE_INVALID; 
    }
    try {
        return map_cpp_to_c_storage_type(plaintext->cpp_plaintext->get_storage_type());
    } catch (...) { return C_STORAGE_TYPE_INVALID; }
}

size_t HEonGPU_CKKS_Plaintext_GetData(HE_CKKS_Plaintext* plaintext,
                                      uint64_t* data_buffer, // heongpu::Data64 is uint64_t
                                      size_t buffer_elements,
                                      C_cudaStream_t stream) {
    if (!plaintext || !plaintext->cpp_plaintext || (!data_buffer && buffer_elements > 0)) {
        std::cerr << "Error: Invalid arguments in Plaintext GetData." << std::endl;
        return 0;
    }
    try {
        heongpu::HostVector<heongpu::Data64> temp_host_vector;
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream);
        
        plaintext->cpp_plaintext->get_data(temp_host_vector, cpp_stream);

        size_t elements_in_pt = temp_host_vector.size();
        size_t elements_to_copy = std::min(buffer_elements, elements_in_pt);

        if (elements_to_copy > 0 && data_buffer) {
            std::memcpy(data_buffer, temp_host_vector.data(), elements_to_copy * sizeof(heongpu::Data64));
        }
        return elements_to_copy;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Plaintext_GetData failed with C++ exception: " << e.what() << std::endl;
        return 0;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Plaintext_GetData failed due to an unknown C++ exception." << std::endl;
        return 0;
    }
}

// --- CKKS Plaintext Setters ---
int HEonGPU_CKKS_Plaintext_SetData(HE_CKKS_Plaintext* plaintext,
                                   const uint64_t* data_buffer, // heongpu::Data64 is uint64_t
                                   size_t num_elements,
                                   C_cudaStream_t stream) {
    if (!plaintext || !plaintext->cpp_plaintext || (!data_buffer && num_elements > 0)) {
        std::cerr << "Error: Invalid arguments in Plaintext SetData." << std::endl;
        return -1; // Error
    }
    try {
        // Create a HostVector from the C buffer.
        // Note: This makes a copy. If Plaintext::set_data takes a const ref
        // and potentially copies internally, this is fine. If it expects to take
        // ownership or avoid a copy, the C++ API would need to reflect that.
        heongpu::HostVector<heongpu::Data64> input_host_vector(num_elements);
        if (num_elements > 0 && data_buffer) {
            std::memcpy(input_host_vector.data(), data_buffer, num_elements * sizeof(heongpu::Data64));
        }
        
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream);
        plaintext->cpp_plaintext->set_data(input_host_vector, cpp_stream);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Plaintext_SetData failed with C++ exception: " << e.what() << std::endl;
        return -2; // Error
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Plaintext_SetData failed due to an unknown C++ exception." << std::endl;
        return -2; // Error
    }
}

} // extern "C"