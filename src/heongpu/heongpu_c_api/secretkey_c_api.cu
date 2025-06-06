#include "secretkey_c_api.h"
#include "heongpu_c_api_internal.h"
#include "heongpu.cuh"

#include "ckks/context.cuh"
#include "ckks/secretkey.cuh" // The C++ class we are wrapping
#include "hostvector.cuh"
#include "schemes.h"
#include "storagemanager.cuh"

#include <vector>
#include <sstream>
#include <iostream>
#include <algorithm> // For std::min
#include <cstring>   // For std::memcpy
#include <new>       // For std::nothrow

// Define the opaque struct
typedef struct HE_CKKS_SecretKey_s HE_CKKS_SecretKey;
// Helper to safely access underlying C++ HEContext pointer
static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context(HE_CKKS_Context* context) {
    if (!context || !context->cpp_context) { // Assuming cpp_context from context_c_api.cu
        std::cerr << "Error: Invalid HE_CKKS_Context pointer." << std::endl;
        return nullptr;
    }
    return context->cpp_context;
}

// Helper to map C++ scheme_type to C_scheme_type (should be in a common C API util or context_c_api.cu)
static C_scheme_type map_cpp_to_c_scheme_type_sk(heongpu::scheme_type cpp_type) {
    switch (cpp_type) {
        case heongpu::scheme_type::none: return C_SCHEME_TYPE_NONE;
        case heongpu::scheme_type::bfv:  return C_SCHEME_TYPE_BFV;
        case heongpu::scheme_type::ckks: return C_SCHEME_TYPE_CKKS;
        case heongpu::scheme_type::bgv:  return C_SCHEME_TYPE_BGV;
        default: return static_cast<C_scheme_type>(-1); // Error/Unknown
    }
}

// Helper to map C++ storage_type to C_storage_type (should be in a common C API util or context_c_api.cu)
static C_storage_type map_cpp_to_c_storage_type_sk(heongpu::storage_type cpp_type) {
    switch (cpp_type) {
        case heongpu::storage_type::HOST:   return C_STORAGE_TYPE_HOST;
        case heongpu::storage_type::DEVICE: return C_STORAGE_TYPE_DEVICE;
        default: return C_STORAGE_TYPE_INVALID;
    }
}

extern "C" {

// --- CKKS SecretKey Lifecycle & Serialization ---

HE_CKKS_SecretKey* HEonGPU_CKKS_SecretKey_Create(HE_CKKS_Context* context) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Create failed: HE_CKKS_Context is null or invalid." << std::endl;
        return nullptr;
    }
    try {
        // Uses the constructor SecretKey(HEContext<Scheme::CKKS>& context);
        heongpu::Secretkey<heongpu::Scheme::CKKS>* cpp_sk_obj =
            new (std::nothrow) heongpu::Secretkey<heongpu::Scheme::CKKS>(*cpp_h_context);
        if (!cpp_sk_obj) {
            std::cerr << "HEonGPU_CKKS_SecretKey_Create failed: C++ SecretKey allocation failed." << std::endl;
            return nullptr;
        }

        HE_CKKS_SecretKey* c_api_sk = new (std::nothrow) HE_CKKS_SecretKey_s;
        if (!c_api_sk) {
            std::cerr << "HEonGPU_CKKS_SecretKey_Create failed: C API SecretKey wrapper allocation failed." << std::endl;
            delete cpp_sk_obj;
            return nullptr;
        }
        c_api_sk->cpp_secretkey = cpp_sk_obj;
        return c_api_sk;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Create failed with C++ exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Create failed due to an unknown C++ exception." << std::endl;
        return nullptr;
    }
}

void HEonGPU_CKKS_SecretKey_Delete(HE_CKKS_SecretKey* sk) {
    if (sk) {
        delete sk->cpp_secretkey;
        delete sk;
    }
}

HE_CKKS_SecretKey* HEonGPU_CKKS_SecretKey_Clone(const HE_CKKS_SecretKey* other_sk) {
    if (!other_sk || !other_sk->cpp_secretkey) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Clone failed: Invalid source secret key pointer." << std::endl;
        return nullptr;
    }
    try {
        heongpu::Secretkey<heongpu::Scheme::CKKS>* cpp_cloned_sk =
            new (std::nothrow) heongpu::Secretkey<heongpu::Scheme::CKKS>(*(other_sk->cpp_secretkey));
         if (!cpp_cloned_sk) {
            std::cerr << "HEonGPU_CKKS_SecretKey_Clone failed: C++ SecretKey (clone) allocation failed." << std::endl;
            return nullptr;
        }
        HE_CKKS_SecretKey* c_api_cloned_sk = new (std::nothrow) HE_CKKS_SecretKey_s;
        if (!c_api_cloned_sk) {
            std::cerr << "HEonGPU_CKKS_SecretKey_Clone failed: C API SecretKey wrapper (clone) allocation failed." << std::endl;
            delete cpp_cloned_sk;
            return nullptr;
        }
        c_api_cloned_sk->cpp_secretkey = cpp_cloned_sk;
        return c_api_cloned_sk;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Clone failed with C++ exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Clone failed due to an unknown C++ exception." << std::endl;
        return nullptr;
    }
}

int HEonGPU_CKKS_SecretKey_Assign_Copy(HE_CKKS_SecretKey* dest_sk,
                                       const HE_CKKS_SecretKey* src_sk) {
    if (!dest_sk || !dest_sk->cpp_secretkey || !src_sk || !src_sk->cpp_secretkey) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Assign_Copy failed: Invalid destination or source secret key pointer." << std::endl;
        return -1; 
    }
    try {
        *(dest_sk->cpp_secretkey) = *(src_sk->cpp_secretkey);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Assign_Copy failed with C++ exception: " << e.what() << std::endl;
        return -2;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Assign_Copy failed due to an unknown C++ exception." << std::endl;
        return -2;
    }
}

int HEonGPU_CKKS_SecretKey_Save(HE_CKKS_SecretKey* sk,
                                unsigned char** out_bytes,
                                size_t* out_len) {
    if (!sk || !sk->cpp_secretkey || !out_bytes || !out_len) {
        if(out_bytes) *out_bytes = nullptr;
        if(out_len) *out_len = 0;
        return -1;
    }
    *out_bytes = nullptr;
    *out_len = 0;
    try {
        std::ostringstream oss(std::ios::binary);
        sk->cpp_secretkey->save(oss);
        std::string str_data = oss.str();
        *out_len = str_data.length();
        if (*out_len == 0) {
            *out_bytes = nullptr;
            return 0; 
        }
        *out_bytes = static_cast<unsigned char*>(malloc(*out_len));
        if (!(*out_bytes)) {
            *out_len = 0;
            std::cerr << "HEonGPU_CKKS_SecretKey_Save failed: Memory allocation error." << std::endl;
            return -2;
        }
        std::memcpy(*out_bytes, str_data.data(), *out_len);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Save failed with C++ exception: " << e.what() << std::endl;
        if(*out_bytes) { free(*out_bytes); *out_bytes = nullptr; }
        *out_len = 0;
        return -3;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Save failed due to an unknown C++ exception." << std::endl;
        if(*out_bytes) { free(*out_bytes); *out_bytes = nullptr; }
        *out_len = 0;
        return -3;
    }
}

HE_CKKS_SecretKey* HEonGPU_CKKS_SecretKey_Load(HE_CKKS_Context* context,
                                               const unsigned char* bytes,
                                               size_t len) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Load failed: HE_CKKS_Context is null or invalid." << std::endl;
        return nullptr;
    }
    if (!bytes && len > 0) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Load failed: Invalid bytes pointer for non-zero length." << std::endl;
        return nullptr;
    }

    HE_CKKS_SecretKey* c_api_sk = nullptr;
    heongpu::Secretkey<heongpu::Scheme::CKKS>* cpp_sk = nullptr;
    try {
        // Create a SecretKey object using the context, then load into it.
        cpp_sk = new (std::nothrow) heongpu::Secretkey<heongpu::Scheme::CKKS>(*cpp_h_context);
        if (!cpp_sk) {
             std::cerr << "HEonGPU_CKKS_SecretKey_Load failed: C++ SecretKey allocation failed." << std::endl;
            return nullptr;
        }

        if (len > 0 && bytes) {
            std::string str_data(reinterpret_cast<const char*>(bytes), len);
            std::istringstream iss(str_data, std::ios::binary);
            cpp_sk->load(iss);
        }
        // If len is 0, cpp_sk is a newly constructed (default) secret key for that context.

        c_api_sk = new (std::nothrow) HE_CKKS_SecretKey_s;
        if (!c_api_sk) {
            std::cerr << "HEonGPU_CKKS_SecretKey_Load failed: C API SecretKey wrapper allocation failed." << std::endl;
            delete cpp_sk;
            return nullptr;
        }
        c_api_sk->cpp_secretkey = cpp_sk;
        return c_api_sk;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Load failed with C++ exception: " << e.what() << std::endl;
        delete cpp_sk;
        delete c_api_sk;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_SecretKey_Load failed due to an unknown C++ exception." << std::endl;
        delete cpp_sk;
        delete c_api_sk;
        return nullptr;
    }
}

// --- CKKS SecretKey Getters ---


int HEonGPU_CKKS_SecretKey_GetRingSize(HE_CKKS_SecretKey* sk) {
    if (!sk || !sk->cpp_secretkey) return 0;
    try { return sk->cpp_secretkey->ring_size(); } catch (...) { return 0; }
}

int HEonGPU_CKKS_SecretKey_GetCoeffModulusCount(HE_CKKS_SecretKey* sk) {
    if (!sk || !sk->cpp_secretkey) return 0;
    try { return sk->cpp_secretkey->coeff_modulus_count(); } catch (...) { return 0; }
}


bool HEonGPU_CKKS_SecretKey_IsOnDevice(HE_CKKS_SecretKey* sk) {
    if (!sk || !sk->cpp_secretkey) return false;
    try { return (sk->cpp_secretkey->is_on_device()); } catch (...) { return false; }
}

uint64_t* HEonGPU_CKKS_SecretKey_GetData(HE_CKKS_SecretKey* sk) {
    if (!sk || !sk->cpp_secretkey) {
        std::cerr << "Error: Invalid arguments in SecretKey GetData." << std::endl;
        return 0;
    }
    try {
        return reinterpret_cast<uint64_t*>(sk->cpp_secretkey->data());
        
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_SecretKey_GetData failed with C++ exception: " << e.what() << std::endl;
        return 0;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_SecretKey_GetData failed due to an unknown C++ exception." << std::endl;
        return 0;
    }
}

} // extern "C"