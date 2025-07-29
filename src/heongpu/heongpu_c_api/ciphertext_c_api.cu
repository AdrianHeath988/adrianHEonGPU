#include "ciphertext_c_api.h"
#include "heongpu_c_api_internal.h"
#include "heongpu.cuh"
#include "memorypool.cuh"

#include "ckks/context.cuh"
#include "ckks/ciphertext.cuh"
#include "hostvector.cuh" // For heongpu::HostVector
#include "schemes.h"      // For heongpu::Data64 (uint64_t)
#include "storagemanager.cuh" // For heongpu::storage_type

#include <vector>
#include <sstream>
#include <iostream>
#include <algorithm>
#include <cstring>
#include <new>

typedef struct HE_CKKS_Ciphertext_s HE_CKKS_Ciphertext;

static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context(HE_CKKS_Context* context) {
    if (!context || !context->cpp_context) {
        std::cerr << "Error: Invalid HE_CKKS_Context pointer provided." << std::endl;
        return nullptr;
    }
    return context->cpp_context;
}

// Helper to map C++ storage_type to C_storage_type
static C_storage_type map_cpp_to_c_storage_type(heongpu::storage_type cpp_type) {
    switch (cpp_type) {
        case heongpu::storage_type::HOST:   return C_STORAGE_TYPE_HOST;
        case heongpu::storage_type::DEVICE: return C_STORAGE_TYPE_DEVICE;
        default:
            // Should not happen with a valid C++ enum
            return static_cast<C_storage_type>(-1); // Indicate error/unknown
    }
}
static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context_from_opaque_ct(HE_CKKS_Context* context_c_api_ptr) {
    if (!context_c_api_ptr || !context_c_api_ptr->cpp_context) {
        std::cerr << "Error: Invalid HE_CKKS_Context pointer." << std::endl;
        return nullptr;
    }
    return context_c_api_ptr->cpp_context;
}
static heongpu::ExecutionOptions map_c_to_cpp_execution_options_ct(const C_ExecutionOptions* c_options) {
    heongpu::ExecutionOptions cpp_options; // Defaults from C++ struct definition
    if (c_options) {
        cpp_options.stream_ = static_cast<cudaStream_t>(c_options->stream);
        if (c_options->storage == C_STORAGE_TYPE_HOST) {
            cpp_options.storage_ = heongpu::storage_type::HOST;
        } else if (c_options->storage == C_STORAGE_TYPE_DEVICE) {
            cpp_options.storage_ = heongpu::storage_type::DEVICE;
        } else {
            // Keep default or handle C_STORAGE_TYPE_INVALID if it's a possible input
            cpp_options.storage_ = heongpu::storage_type::DEVICE; // Defaulting to DEVICE
        }
        cpp_options.keep_initial_condition_ = c_options->keep_initial_condition;
    }
    return cpp_options;
}

extern "C" {

// --- Lifecycle & Serialization (from previous version, with minor safety improvements) ---

HE_CKKS_Ciphertext* HEonGPU_CKKS_Ciphertext_Create(HE_CKKS_Context* context_c_api_ptr,
                                                   const C_ExecutionOptions* options_c) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context_from_opaque_ct(context_c_api_ptr);
    if (!cpp_h_context) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Create failed: HE_CKKS_Context is null or invalid." << std::endl;
        return nullptr;
    }

    try {
        heongpu::ExecutionOptions cpp_exec_options = map_c_to_cpp_execution_options_ct(options_c);
        heongpu::Ciphertext<heongpu::Scheme::CKKS>* cpp_ct =
            new (std::nothrow) heongpu::Ciphertext<heongpu::Scheme::CKKS>(*cpp_h_context, cpp_exec_options);
        
        if (!cpp_ct) {
            std::cerr << "HEonGPU_CKKS_Ciphertext_Create failed: C++ Ciphertext allocation failed." << std::endl;
            return nullptr;
        }

        HE_CKKS_Ciphertext* c_api_ciphertext = new (std::nothrow) HE_CKKS_Ciphertext_s;
        if (!c_api_ciphertext) {
            std::cerr << "HEonGPU_CKKS_Ciphertext_Create failed: C API Ciphertext wrapper allocation failed." << std::endl;
            delete cpp_ct; 
            return nullptr;
        }
        c_api_ciphertext->cpp_ciphertext = cpp_ct;
        return c_api_ciphertext;

    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Create failed with C++ exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Create failed due to an unknown C++ exception." << std::endl;
        return nullptr;
    }
}


void HEonGPU_CKKS_Ciphertext_Delete(HE_CKKS_Ciphertext* ciphertext) {
    // This function should ONLY delete the C++ object pointed to by the wrapper.
    // The C-style wrapper struct (ciphertext) itself will be freed by the
    // calling language's runtime (Python's garbage collector in this case).
    if (ciphertext && ciphertext->cpp_ciphertext) {

        // std::cout <<"[C++ Debug] Before CipherText Deletion"<<std::endl;
        // MemoryPool::instance().print_memory_pool_status();

        cudaStream_t stream = ciphertext->cpp_ciphertext->stream();
        ciphertext->cpp_ciphertext->memory_clear(stream);
        delete ciphertext->cpp_ciphertext;
        ciphertext->cpp_ciphertext = nullptr;
        HEonGPU_SynchronizeDevice();
        // std::cout <<"[C++ Debug] After CipherText Deletion"<<std::endl;
        // MemoryPool::instance().print_memory_pool_status();

    }
}


HE_CKKS_Ciphertext* HEonGPU_CKKS_Ciphertext_Clone(const HE_CKKS_Ciphertext* other_ciphertext) {
    if (!other_ciphertext || !other_ciphertext->cpp_ciphertext) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Clone failed: Invalid source ciphertext pointer." << std::endl;
        return nullptr;
    }
    try {
        heongpu::Ciphertext<heongpu::Scheme::CKKS>* cpp_cloned_ct =
            new (std::nothrow) heongpu::Ciphertext<heongpu::Scheme::CKKS>(*(other_ciphertext->cpp_ciphertext));
        if (!cpp_cloned_ct) {
            std::cerr << "HEonGPU_CKKS_Ciphertext_Clone failed: C++ Ciphertext (clone) allocation failed." << std::endl;
            return nullptr;
        }
        HE_CKKS_Ciphertext* c_api_cloned_ciphertext = new (std::nothrow) HE_CKKS_Ciphertext_s;
        if (!c_api_cloned_ciphertext) {
            std::cerr << "HEonGPU_CKKS_Ciphertext_Clone failed: C API Ciphertext wrapper (clone) allocation failed." << std::endl;
            delete cpp_cloned_ct;
            return nullptr;
        }
        c_api_cloned_ciphertext->cpp_ciphertext = cpp_cloned_ct;
        return c_api_cloned_ciphertext;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Clone failed with C++ exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Clone failed due to an unknown C++ exception." << std::endl;
        return nullptr;
    }
}

int HEonGPU_CKKS_Ciphertext_Assign_Copy(HE_CKKS_Ciphertext* dest_ciphertext,
                                        const HE_CKKS_Ciphertext* src_ciphertext) {
    if (!dest_ciphertext || !dest_ciphertext->cpp_ciphertext ||
        !src_ciphertext || !src_ciphertext->cpp_ciphertext) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Assign_Copy failed: Invalid destination or source ciphertext pointer." << std::endl;
        return -1; 
    }
    try {
        *(dest_ciphertext->cpp_ciphertext) = *(src_ciphertext->cpp_ciphertext);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Assign_Copy failed with C++ exception: " << e.what() << std::endl;
        return -2;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Assign_Copy failed due to an unknown C++ exception." << std::endl;
        return -2;
    }
}

int HEonGPU_CKKS_Ciphertext_Save(HE_CKKS_Ciphertext* ciphertext,
                                 unsigned char** out_bytes,
                                 size_t* out_len) {
    if (!ciphertext || !ciphertext->cpp_ciphertext || !out_bytes || !out_len) {
        if (out_bytes) *out_bytes = nullptr;
        if (out_len) *out_len = 0;
        return -1; 
    }
    *out_bytes = nullptr; 
    *out_len = 0;
    try {
        std::ostringstream oss(std::ios::binary);
        ciphertext->cpp_ciphertext->save(oss);
        std::string str_data = oss.str();
        *out_len = str_data.length();
        if (*out_len == 0) {
             *out_bytes = nullptr; 
             return 0; 
        }
        *out_bytes = static_cast<unsigned char*>(malloc(*out_len));
        if (!(*out_bytes)) {
            *out_len = 0;
            std::cerr << "HEonGPU_CKKS_Ciphertext_Save failed: Memory allocation error." << std::endl;
            return -2;
        }
        std::memcpy(*out_bytes, str_data.data(), *out_len);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Save failed with C++ exception: " << e.what() << std::endl;
        if (*out_bytes) { free(*out_bytes); *out_bytes = nullptr; }
        *out_len = 0;
        return -3;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Save failed due to an unknown C++ exception." << std::endl;
        if (*out_bytes) { free(*out_bytes); *out_bytes = nullptr; }
        *out_len = 0;
        return -3;
    }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_Ciphertext_Load(HE_CKKS_Context* context_c_api_ptr,
                                                 const unsigned char* bytes,
                                                 size_t len,
                                                 const C_ExecutionOptions* options_c) { // CHANGED
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context_from_opaque_ct(context_c_api_ptr);
    if (!cpp_h_context) { return nullptr; }
    if (!bytes && len > 0) { return nullptr; }

    HE_CKKS_Ciphertext* c_api_ciphertext = nullptr;
    heongpu::Ciphertext<heongpu::Scheme::CKKS>* cpp_ct = nullptr;
    try {
        heongpu::ExecutionOptions cpp_exec_options = map_c_to_cpp_execution_options_ct(options_c);
        cpp_ct = new (std::nothrow) heongpu::Ciphertext<heongpu::Scheme::CKKS>(*cpp_h_context, cpp_exec_options); // CHANGED CALL
        if (!cpp_ct) { return nullptr; }

        if (len > 0 && bytes) { 
            std::string str_data(reinterpret_cast<const char*>(bytes), len);
            std::istringstream iss(str_data, std::ios::binary);
            cpp_ct->load(iss); 
        }
        
        c_api_ciphertext = new (std::nothrow) HE_CKKS_Ciphertext_s;
        if (!c_api_ciphertext) { delete cpp_ct; return nullptr; }
        c_api_ciphertext->cpp_ciphertext = cpp_ct;
        return c_api_ciphertext;
    } catch (...) { delete cpp_ct; delete c_api_ciphertext; return nullptr; }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_Ciphertext_Set_Scale(HE_CKKS_Ciphertext* ciphertext, double scale){
    if (!ciphertext || !ciphertext->cpp_ciphertext) {
        std::cerr << "Error: Invalid ciphertext pointer in HEonGPU_CKKS_Ciphertext_Set_Scale." << std::endl;
        return 0; 
    }
    try {
        ciphertext->cpp_ciphertext->set_scale(scale);
        std::cout << "Scale has been set to " << scale << std::endl;
        return ciphertext;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Set_Scale failed with C++ exception: " << e.what() << std::endl;
        return 0; // Or error indicator
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_Set_Scale failed due to an unknown C++ exception." << std::endl;
        return 0; // Or error indicator
    }
}
// --- CKKS Ciphertext Getters ---

int HEonGPU_CKKS_Ciphertext_GetRingSize(HE_CKKS_Ciphertext* ciphertext) {
    if (!ciphertext || !ciphertext->cpp_ciphertext) {
        std::cerr << "Error: Invalid ciphertext pointer in GetRingSize." << std::endl;
        return 0; // 0 is not a valid ring size (indicates error)
    }
    try {
        // Ciphertext<CKKS> has a public method like:
        // inline int ring_size() const noexcept { return ring_size_; }
        return ciphertext->cpp_ciphertext->ring_size();
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_GetRingSize failed with C++ exception: " << e.what() << std::endl;
        return 0; // Or error indicator
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_GetRingSize failed due to an unknown C++ exception." << std::endl;
        return 0; // Or error indicator
    }
}

int HEonGPU_CKKS_Ciphertext_GetCoeffModulusCount(HE_CKKS_Ciphertext* ciphertext) {
    if (!ciphertext || !ciphertext->cpp_ciphertext) {
        std::cerr << "Error: Invalid ciphertext pointer in GetCoeffModulusCount." << std::endl;
        return 0; 
    }
    try {
        // Ciphertext<CKKS> has a public method like:
        // inline int coeff_modulus_count() const noexcept { return coeff_modulus_count_; }
        return ciphertext->cpp_ciphertext->coeff_modulus_count();
    } catch (...) { return 0; } // Simplified error handling for getters
}

int HEonGPU_CKKS_Ciphertext_GetCiphertextSize(HE_CKKS_Ciphertext* ciphertext) {
    if (!ciphertext || !ciphertext->cpp_ciphertext) {
        std::cerr << "Error: Invalid ciphertext pointer in GetCiphertextSize." << std::endl;
        return 0;
    }
    try {
        // Ciphertext<CKKS> has a public method like:
        // inline int cipher_size() const noexcept { return cipher_size_; }
        return ciphertext->cpp_ciphertext->size();
    } catch (...) { return 0; }
}

double HEonGPU_CKKS_Ciphertext_GetScale(HE_CKKS_Ciphertext* ciphertext) {
    if (!ciphertext || !ciphertext->cpp_ciphertext) {
        std::cerr << "Error: Invalid ciphertext pointer in GetScale." << std::endl;
        return -1.0; // Error indicator
    }
    try {
        // Ciphertext<CKKS> has a public method like:
        // inline double get_scale() const noexcept { return scale_; }
        return ciphertext->cpp_ciphertext->scale();
    } catch (...) { return -1.0; }
}

bool HEonGPU_CKKS_Ciphertext_IsInNttDomain(HE_CKKS_Ciphertext* ciphertext) {
    if (!ciphertext || !ciphertext->cpp_ciphertext) {
        std::cerr << "Error: Invalid ciphertext pointer in IsInNttDomain." << std::endl;
        return false; // Default / error
    }
    try {
        // Ciphertext<CKKS> has a public method like:
        // inline bool is_in_ntt_domain() const noexcept { return in_ntt_domain_; }
        return ciphertext->cpp_ciphertext->in_ntt_domain();
    } catch (...) { return false; }
}
int HEonGPU_CKKS_Ciphertext_GetDepth(HE_CKKS_Ciphertext* ciphertext) {
    if (!ciphertext || !ciphertext->cpp_ciphertext) {
        std::cerr << "Error: Invalid ciphertext pointer in GetDepth." << std::endl;
        return 0;
    }
    try {
        return ciphertext->cpp_ciphertext->depth();
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_GetDepth failed with C++ exception: " << e.what() << std::endl;
        return 0;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_GetDepth failed due to an unknown C++ exception." << std::endl;
        return 0;
    }
}

bool HEonGPU_CKKS_Ciphertext_Is_On_Device(HE_CKKS_Ciphertext* ciphertext) {
    if (!ciphertext || !ciphertext->cpp_ciphertext) {
        std::cerr << "Error: Invalid ciphertext pointer in GetStorageType." << std::endl;
        return static_cast<C_storage_type>(-1); // Error indicator
    }
    try {
        // Ciphertext<CKKS> has a public method like:
        // inline heongpu::storage_type get_storage_type() const noexcept { return storage_type_; }
        return ciphertext->cpp_ciphertext->is_on_device();
    } catch (...) { return static_cast<C_storage_type>(-1); }
}

size_t HEonGPU_CKKS_Ciphertext_GetData(HE_CKKS_Ciphertext* ciphertext,
                                       uint64_t* data_buffer, // C++ Data64 is uint64_t
                                       size_t buffer_elements,
                                       C_cudaStream_t stream) {
    if (!ciphertext || !ciphertext->cpp_ciphertext || !data_buffer) {
        std::cerr << "Error: Invalid arguments in GetData." << std::endl;
        return 0;
    }
    try {
        // Ciphertext<CKKS> has a public method like:
        // void get_data(HostVector<Data64>& cipher_coeffs_data_on_host, cudaStream_t stream = cudaStreamDefault);
        // This C++ method populates a HostVector, For C, we fill a user-provided buffer
        // The C++ get_data would likely handle copying from device to a temporary HostVector if needed

        // Create a temporary C++ HostVector to receive the data.
        heongpu::HostVector<Data64> temp_host_vector;
        
        // Call the C++ method.
        // The C++ method itself needs to be able to determine how many elements to copy based on its internal state
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream);
        ciphertext->cpp_ciphertext->get_data(temp_host_vector, cpp_stream);

        // Copy from the temporary HostVector to the user's buffer.
        size_t elements_in_ct = temp_host_vector.size();
        size_t elements_to_copy = std::min(buffer_elements, elements_in_ct);

        if (elements_to_copy > 0) {
            std::memcpy(data_buffer, temp_host_vector.data(), elements_to_copy * sizeof(Data64));
        }
        
        // If buffer_elements < elements_in_ct, it's a partial copy
        // return how many were copied
        return elements_to_copy;

    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_GetData failed with C++ exception: " << e.what() << std::endl;
        return 0;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Ciphertext_GetData failed due to an unknown C++ exception." << std::endl;
        return 0;
    }
}


} // extern "C"