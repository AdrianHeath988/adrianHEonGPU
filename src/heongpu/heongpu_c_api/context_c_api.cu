#include "context_c_api.h"
#include "heongpu_c_api_internal.h"
#include "heongpu.cuh" // Main HEonGPU include for HEContext, Scheme, types
#include "schemes.h"      // For heongpu::Scheme, heongpu::keyswitching_type
#include "secstdparams.h" // For heongpu::sec_level_type
#include "hostvector.cuh" // For heongpu::HostVector
#include "util.cuh"       // For heongpu::Data128, heongpu::Modulus64 (via modular_arith.cuh)
#include <cuda_runtime.h>

#include <vector>
#include <iostream> // For potential error logging (stderr)
#include <sstream>  // For serialization to/from memory buffer
#include <algorithm> // For std::copy, std::min

// Define the opaque struct to hold the actual C++ HEContext object
typedef struct HE_CKKS_Context_s HE_CKKS_Context;

// Helper to map C enum to C++ enum for keyswitching_type
static heongpu::keyswitching_type map_c_keyswitch_type(C_keyswitching_type c_type) {
    switch (c_type) {
        case C_KEYSWITCHING_METHOD_I: return heongpu::keyswitching_type::KEYSWITCHING_METHOD_I;
        case C_KEYSWITCHING_METHOD_II: return heongpu::keyswitching_type::KEYSWITCHING_METHOD_II;
        default:
            // Handle error or default, though C enum should prevent invalid values if used correctly
            return heongpu::keyswitching_type::KEYSWITCHING_METHOD_I; // Fallback, consider error
    }
}

// Helper to map C enum to C++ enum for sec_level_type
static heongpu::sec_level_type map_c_sec_level(C_sec_level_type c_sec) {
    switch (c_sec) {
        case C_SEC_LEVEL_TYPE_NONE: return heongpu::sec_level_type::none;
        case C_SEC_LEVEL_TYPE_128: return heongpu::sec_level_type::sec128;
        case C_SEC_LEVEL_TYPE_192: return heongpu::sec_level_type::sec192;
        case C_SEC_LEVEL_TYPE_256: return heongpu::sec_level_type::sec256;
        default:
            return heongpu::sec_level_type::sec128; // Fallback
    }
}

void HEonGPU_Free_C_RNGSeed_Data_Members(C_RNGSeed_Data* seed_data) {
    if (seed_data) {
        if (seed_data->key_data) free(seed_data->key_data);
        if (seed_data->nonce_data) free(seed_data->nonce_data);
        if (seed_data->pstring_data) free(seed_data->pstring_data);
        seed_data->key_data = nullptr; seed_data->key_len = 0;
        seed_data->nonce_data = nullptr; seed_data->nonce_len = 0;
        seed_data->pstring_data = nullptr; seed_data->pstring_len = 0;
    }
}
extern "C" {

int HEonGPU_SynchronizeDevice() {
    cudaError_t err = cudaDeviceSynchronize();
    return static_cast<int>(err);
}

HE_CKKS_Context* HEonGPU_CKKS_Context_Create(C_keyswitching_type method,
                                             C_sec_level_type sec_level) {
    try {
        heongpu::keyswitching_type cpp_method = map_c_keyswitch_type(method);
        heongpu::sec_level_type cpp_sec_level = map_c_sec_level(sec_level);

        heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_ctx =
            new heongpu::HEContext<heongpu::Scheme::CKKS>(cpp_method, cpp_sec_level);

        HE_CKKS_Context* c_api_context = new HE_CKKS_Context_s;
        c_api_context->cpp_context = cpp_ctx;
        return c_api_context;
    } catch (const std::exception& e) {
        // Consider logging e.what()
        std::cerr << "HEonGPU_CKKS_Context_Create failed: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Context_Create failed due to an unknown exception." << std::endl;
        return nullptr;
    }
}

void HEonGPU_CKKS_Context_Delete(HE_CKKS_Context* context) {
    if (context) {
        delete context->cpp_context;
        delete context;
    }
}

void HEonGPU_CKKS_Context_SetPolyModulusDegree(HE_CKKS_Context* context, size_t degree) {
    if (context && context->cpp_context) {
        try {
            context->cpp_context->set_poly_modulus_degree(degree);
        } catch (const std::exception& e) {
            std::cerr << "HEonGPU_CKKS_Context_SetPolyModulusDegree failed: " << e.what() << std::endl;
        } catch (...) {
            std::cerr << "HEonGPU_CKKS_Context_SetPolyModulusDegree failed due to an unknown exception." << std::endl;
        }
    }
}

int HEonGPU_CKKS_Context_SetCoeffModulusValues(HE_CKKS_Context* context,
                                               const uint64_t* log_q_bases_data,
                                               size_t log_q_bases_len,
                                               const uint64_t* log_p_bases_data,
                                               size_t log_p_bases_len) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = context->cpp_context;

    if (!cpp_h_context) {
        std::cerr << "HEonGPU_CKKS_Context_SetCoeffModulusValues failed: Invalid context pointer." << std::endl;
        return -1; // Error
    }
    if ((log_q_bases_len > 0 && !log_q_bases_data) || (log_p_bases_len > 0 && !log_p_bases_data)) {
        std::cerr << "HEonGPU_CKKS_Context_SetCoeffModulusValues failed: Non-zero length with null data pointer." << std::endl;
        return -1; // Error for inconsistent arguments
    }

    try {
        std::vector<Data64> cpp_log_q_bases;
        if (log_q_bases_len > 0) {
            cpp_log_q_bases.assign(log_q_bases_data, log_q_bases_data + log_q_bases_len);
        }

        std::vector<Data64> cpp_log_p_bases;
        if (log_p_bases_len > 0) {
            cpp_log_p_bases.assign(log_p_bases_data, log_p_bases_data + log_p_bases_len);
        }
        
        cpp_h_context->set_coeff_modulus_values(cpp_log_q_bases, cpp_log_p_bases);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Context_SetCoeffModulusValues failed with C++ exception: " << e.what() << std::endl;
        return -2; // Error
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Context_SetCoeffModulusValues failed due to an unknown C++ exception." << std::endl;
        return -2; // Error
    }
}

int HEonGPU_CKKS_Context_SetCoeffModulusBitSizes(HE_CKKS_Context* context,
                                                 const int* log_q_bit_sizes_data,
                                                 size_t log_q_bit_sizes_len,
                                                 const int* log_p_bit_sizes_data,
                                                 size_t log_p_bit_sizes_len) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = (context->cpp_context);

    if (!cpp_h_context) {
        std::cerr << "HEonGPU_CKKS_Context_SetCoeffModulusBitSizes failed: Invalid context pointer." << std::endl;
        return -1;
    }
    if ((log_q_bit_sizes_len > 0 && !log_q_bit_sizes_data) || (log_p_bit_sizes_len > 0 && !log_p_bit_sizes_data)) {
        std::cerr << "HEonGPU_CKKS_Context_SetCoeffModulusBitSizes failed: Non-zero length with null data pointer." << std::endl;
        return -1;
    }

    try {
        std::vector<int> cpp_log_q_bit_sizes;
        if (log_q_bit_sizes_len > 0) {
            cpp_log_q_bit_sizes.assign(log_q_bit_sizes_data, log_q_bit_sizes_data + log_q_bit_sizes_len);
        }

        std::vector<int> cpp_log_p_bit_sizes;
        if (log_p_bit_sizes_len > 0) {
            cpp_log_p_bit_sizes.assign(log_p_bit_sizes_data, log_p_bit_sizes_data + log_p_bit_sizes_len);
        }
        for(int i=0;i<log_q_bit_sizes_len;i++){
            std::cout << "The cpp_log_q_bit_sizes[i] is: " << cpp_log_q_bit_sizes[i] << std::endl;
        }
        for(int i=0;i<log_p_bit_sizes_len;i++){
            std::cout << "The cpp_log_p_bit_sizes[i] is: " << cpp_log_p_bit_sizes[i] << std::endl;
        }
        cpp_h_context->set_coeff_modulus_bit_sizes(cpp_log_q_bit_sizes, cpp_log_p_bit_sizes);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Context_SetCoeffModulusBitSizes failed with C++ exception: " << e.what() << std::endl;
        return -2;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Context_SetCoeffModulusBitSizes failed due to an unknown C++ exception." << std::endl;
        return -2;
    }
}


void HEonGPU_CKKS_Context_SetExactModulus(HE_CKKS_Context* context, bool exact_mod) {
    if (context && context->cpp_context) {
        try {
            context->cpp_context->set_poly_modulus_degree(exact_mod);
        } catch (const std::exception& e) {
            std::cerr << "HEonGPU_CKKS_Context_SetExactModulus failed: " << e.what() << std::endl;
        } catch (...) {
            std::cerr << "HEonGPU_CKKS_Context_SetExactModulus failed due to an unknown exception." << std::endl;
        }
    }
}

void HEonGPU_CKKS_Context_PrintParameters(HE_CKKS_Context* context){
    if (context && context->cpp_context) {
        context->cpp_context->print_parameters();
    }
}


int HEonGPU_CKKS_Context_Generate(HE_CKKS_Context* context) {
    if (context && context->cpp_context) {
        try {
            context->cpp_context->generate();
            return 0; // Success
        } catch (const std::exception& e) {
            std::cerr << "HEonGPU_CKKS_Context_Generate failed: " << e.what() << std::endl;
            return -1; // Failure
        } catch (...) {
            std::cerr << "HEonGPU_CKKS_Context_Generate failed due to an unknown exception." << std::endl;
            return -1; // Failure
        }
    }
    return -2; // Invalid context pointer
}

size_t HEonGPU_CKKS_Context_GetPolyModulusDegree(HE_CKKS_Context* context) {
    if (context && context->cpp_context) {
        try {
            return context->cpp_context->get_poly_modulus_degree();
        } catch (...) { return 0; }
    }
    return 0;
}

size_t HEonGPU_CKKS_Context_GetCoeffModulusSize(HE_CKKS_Context* context) {
    if (context && context->cpp_context) {
        try {
            return context->cpp_context->get_ciphertext_modulus_count();
        } catch (...) { return 0; }
    }
    return 0;
}

size_t HEonGPU_CKKS_Context_GetCoeffModulus(HE_CKKS_Context* context,
                                          C_Modulus64* moduli_buffer,
                                          size_t buffer_count) {
    if (!context || !context->cpp_context) {
        std::cerr << "C++ DEBUG: GetCoeffModulus called with invalid context." << std::endl;
        return 0;
    }

    try {
        std::vector<Modulus64> cpp_moduli = 
            context->cpp_context->get_key_modulus();

        std::cerr << "--- C++ DEBUG (Forced Flush) ---" << std::endl;
        std::cerr << "Function: HEonGPU_CKKS_Context_GetCoeffModulus" << std::endl;
        std::cerr << "Vector size from get_key_modulus(): " << cpp_moduli.size() << std::endl;
        for (size_t i = 0; i < cpp_moduli.size(); ++i) {
            std::cerr << "  - Modulus[" << i << "]: value = " << cpp_moduli[i].value << std::endl;
        }
        std::cerr << "----------------------------------" << std::endl;
        if (moduli_buffer == NULL) {
            return cpp_moduli.size();
        }
        size_t num_to_copy = std::min(buffer_count, cpp_moduli.size());
        for (size_t i = 0; i < num_to_copy; ++i) {
            moduli_buffer[i].value = cpp_moduli[i].value;
            moduli_buffer[i].bit   = cpp_moduli[i].bit;
            moduli_buffer[i].mu    = cpp_moduli[i].mu;
        }
        return num_to_copy;

    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Context_GetCoeffModulus failed: " << e.what() << std::endl;
        return 0; 
    }
}



// double HEonGPU_CKKS_Context_GetScale(HE_CKKS_Context* context) {
//     if (context && context->cpp_context) {
//         try {
//             return context->cpp_context->[HEONGPU DOES NOT SUPPORT]();
//         } catch (...) { return -1.0; } // Error indication
//     }
//     return -1.0;
// }



int HEonGPU_CKKS_Context_Serialize(HE_CKKS_Context* context, unsigned char** out_bytes, size_t* out_len) {
    if (!context || !context->cpp_context || !out_bytes || !out_len) {
        return -1; // Invalid arguments
    }
    try {
        std::ostringstream oss(std::ios::binary);
        context->cpp_context->save(oss);
        std::string str_data = oss.str();
        
        *out_len = str_data.length();
        *out_bytes = static_cast<unsigned char*>(malloc(*out_len));
        if (!(*out_bytes)) {
            *out_len = 0;
            return -2; // Memory allocation failed
        }
        std::copy(str_data.begin(), str_data.end(), *out_bytes);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Context_Serialize failed: " << e.what() << std::endl;
        if (*out_bytes) { // Should not happen if malloc failed, but defensive
            free(*out_bytes);
            *out_bytes = nullptr;
        }
        *out_len = 0;
        return -3;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Context_Serialize failed due to an unknown exception." << std::endl;
         if (*out_bytes) {
            free(*out_bytes);
            *out_bytes = nullptr;
        }
        *out_len = 0;
        return -3;
    }
}

void HEonGPU_Free_C_RotationIndices_Data_Members(C_RotationIndices_Data* indices_data) {
    if (indices_data) {
        if (indices_data->galois_elements_data) {
            free(indices_data->galois_elements_data);
            indices_data->galois_elements_data = nullptr;
        }
        indices_data->galois_elements_len = 0;
        if (indices_data->rotation_steps_data) {
            free(indices_data->rotation_steps_data);
            indices_data->rotation_steps_data = nullptr;
        }
        indices_data->rotation_steps_len = 0;
    }
}

HE_CKKS_Context* HEonGPU_CKKS_Context_Deserialize(const unsigned char* bytes, size_t len) {
    if (!bytes || len == 0) {
        return nullptr;
    }
    try {
        // Create a temporary HEContext to call the non-static load method.
        // The constructor parameters for this temp object might not matter if load overwrites them,
        // but it's safer to use some defaults. The actual context parameters will come from the stream.
        
        heongpu::keyswitching_type default_ks_type = heongpu::keyswitching_type::KEYSWITCHING_METHOD_I;
        heongpu::sec_level_type default_sec_level = heongpu::sec_level_type::sec128;

        heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_ctx =
            new heongpu::HEContext<heongpu::Scheme::CKKS>(default_ks_type, default_sec_level);

        std::string str_data(reinterpret_cast<const char*>(bytes), len);
        std::istringstream iss(str_data, std::ios::binary);
        cpp_ctx->load(iss); // The load method will populate the cpp_ctx



        HE_CKKS_Context* c_api_context = new HE_CKKS_Context_s;
        c_api_context->cpp_context = cpp_ctx;
        return c_api_context;

    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Context_Deserialize failed: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Context_Deserialize failed due to an unknown exception." << std::endl;
        return nullptr;
    }
}

void HEonGPU_FreeSerializedData(void* data_ptr) {
    if (data_ptr) {
        free(data_ptr);
    }
}

} // extern "C"