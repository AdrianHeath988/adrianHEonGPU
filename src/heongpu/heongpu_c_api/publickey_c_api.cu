#include "publickey_c_api.h"
#include "heongpu_c_api_internal.h"
#include "heongpu.cuh"

#include "ckks/context.cuh"
#include "ckks/publickey.cuh" // The C++ class we are wrapping
#include "hostvector.cuh"
#include "schemes.h"
#include "storagemanager.cuh"
#include "random.cuh"     // For heongpu::RNGSeed

#include <vector>
#include <sstream>
#include <iostream>
#include <algorithm> // For std::min
#include <cstring>   // For std::memcpy
#include <new>       // For std::nothrow


// Define the opaque structs

typedef struct HE_CKKS_PublicKey_s HE_CKKS_PublicKey;

typedef struct HE_CKKS_MultipartyPublicKey_s HE_CKKS_MultipartyPublicKey;
// Helper to safely access underlying C++ HEContext pointer
static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context(HE_CKKS_Context* context) {
    if (!context || !context->cpp_context) {
        std::cerr << "Error: Invalid HE_CKKS_Context pointer." << std::endl;
        return nullptr;
    }
    return context->cpp_context;
}

// Helper C++ enums to C enums 
static C_scheme_type map_cpp_to_c_scheme_type_pk(heongpu::scheme_type cpp_type) {
    switch (cpp_type) {
        case heongpu::scheme_type::none: return C_SCHEME_TYPE_NONE;
        case heongpu::scheme_type::bfv:  return C_SCHEME_TYPE_BFV;
        case heongpu::scheme_type::ckks: return C_SCHEME_TYPE_CKKS;
        case heongpu::scheme_type::bgv:  return C_SCHEME_TYPE_BGV;
        default: return static_cast<C_scheme_type>(-1); 
    }
}

static C_storage_type map_cpp_to_c_storage_type_pk(heongpu::storage_type cpp_type) {
    switch (cpp_type) {
        case heongpu::storage_type::HOST:   return C_STORAGE_TYPE_HOST;
        case heongpu::storage_type::DEVICE: return C_STORAGE_TYPE_DEVICE;
        default: return C_STORAGE_TYPE_INVALID;
    }
}





extern "C" {

// --- CKKS PublicKey Functions ---

HE_CKKS_PublicKey* HEonGPU_CKKS_PublicKey_Create(HE_CKKS_Context* context) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) {
        std::cerr << "HEonGPU_CKKS_PublicKey_Create failed: HE_CKKS_Context is null or invalid." << std::endl;
        return nullptr;
    }
    try {
        heongpu::Publickey<heongpu::Scheme::CKKS>* cpp_pk_obj =
            new (std::nothrow) heongpu::Publickey<heongpu::Scheme::CKKS>(*cpp_h_context);
        if (!cpp_pk_obj) {
            std::cerr << "HEonGPU_CKKS_PublicKey_Create failed: C++ Publickey allocation failed." << std::endl;
            return nullptr;
        }
        HE_CKKS_PublicKey* c_api_pk = new (std::nothrow) HE_CKKS_PublicKey_s;
        if (!c_api_pk) {
            std::cerr << "HEonGPU_CKKS_PublicKey_Create failed: C API Publickey wrapper allocation failed." << std::endl;
            delete cpp_pk_obj;
            return nullptr;
        }
        c_api_pk->cpp_publickey = cpp_pk_obj;
        return c_api_pk;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_PublicKey_Create failed: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_PublicKey_Create failed due to an unknown exception." << std::endl;
        return nullptr;
    }
}

void HEonGPU_CKKS_PublicKey_Delete(HE_CKKS_PublicKey* pk) {
    if (pk) {
        delete pk->cpp_publickey;
        delete pk;
    }
}

HE_CKKS_PublicKey* HEonGPU_CKKS_PublicKey_Clone(const HE_CKKS_PublicKey* other_pk) {
    if (!other_pk || !other_pk->cpp_publickey) return nullptr;
    try {
        auto cpp_clone = new (std::nothrow) heongpu::Publickey<heongpu::Scheme::CKKS>(*(other_pk->cpp_publickey));
        if (!cpp_clone) return nullptr;
        auto c_api_clone = new (std::nothrow) HE_CKKS_PublicKey_s;
        if (!c_api_clone) { delete cpp_clone; return nullptr; }
        c_api_clone->cpp_publickey = cpp_clone;
        return c_api_clone;
    } catch (...) { return nullptr; }
}

int HEonGPU_CKKS_PublicKey_Assign_Copy(HE_CKKS_PublicKey* dest_pk, const HE_CKKS_PublicKey* src_pk) {
    if (!dest_pk || !dest_pk->cpp_publickey || !src_pk || !src_pk->cpp_publickey) return -1;
    try {
        *(dest_pk->cpp_publickey) = *(src_pk->cpp_publickey);
        return 0;
    } catch (...) { return -2; }
}

int HEonGPU_CKKS_PublicKey_Save(HE_CKKS_PublicKey* pk, unsigned char** out_bytes, size_t* out_len) {
    if (!pk || !pk->cpp_publickey || !out_bytes || !out_len) {
        if(out_bytes) *out_bytes = nullptr;
        if(out_len) *out_len = 0;
        return -1;
    }
    *out_bytes = nullptr; *out_len = 0;
    try {
        std::ostringstream oss(std::ios::binary);
        pk->cpp_publickey->save(oss);
        std::string str_data = oss.str();
        *out_len = str_data.length();
        if (*out_len == 0) { *out_bytes = nullptr; return 0; }
        *out_bytes = static_cast<unsigned char*>(malloc(*out_len));
        if (!(*out_bytes)) { *out_len = 0; return -2; }
        std::memcpy(*out_bytes, str_data.data(), *out_len);
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "PK Save failed: " << e.what() << std::endl;
        if(*out_bytes) { free(*out_bytes); *out_bytes = nullptr; } *out_len = 0; return -3;
    } catch (...) {
        if(*out_bytes) { free(*out_bytes); *out_bytes = nullptr; } *out_len = 0; return -3;
    }
}

HE_CKKS_PublicKey* HEonGPU_CKKS_PublicKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    if (!bytes && len > 0) return nullptr;

    heongpu::Publickey<heongpu::Scheme::CKKS>* cpp_pk = nullptr;
    HE_CKKS_PublicKey* c_api_pk = nullptr;
    try {
        cpp_pk = new (std::nothrow) heongpu::Publickey<heongpu::Scheme::CKKS>(*cpp_h_context);
        if (!cpp_pk) return nullptr;
        if (len > 0 && bytes) {
            std::string str_data(reinterpret_cast<const char*>(bytes), len);
            std::istringstream iss(str_data, std::ios::binary);
            cpp_pk->load(iss);
        }
        c_api_pk = new (std::nothrow) HE_CKKS_PublicKey_s;
        if (!c_api_pk) { delete cpp_pk; return nullptr; }
        c_api_pk->cpp_publickey = cpp_pk;
        return c_api_pk;
    } catch (const std::exception& e) {
        std::cerr << "PK Load failed: " << e.what() << std::endl;
        delete cpp_pk; delete c_api_pk; return nullptr;
    } catch (...) {
        delete cpp_pk; delete c_api_pk; return nullptr;
    }
}

// Getters for PublicKey
int HEonGPU_CKKS_PublicKey_GetRingSize(HE_CKKS_PublicKey* pk) {
    if (!pk || !pk->cpp_publickey) return 0;
    try { return pk->cpp_publickey->ring_size(); } catch (...) { return 0; }
}
int HEonGPU_CKKS_PublicKey_GetCoeffModulusCount(HE_CKKS_PublicKey* pk) {
    if (!pk || !pk->cpp_publickey) return 0;
    try { return pk->cpp_publickey->coeff_modulus_count(); } catch (...) { return 0; }
}

bool HEonGPU_CKKS_PublicKey_IsOnDevice(HE_CKKS_PublicKey* pk) {
    if (!pk || !pk->cpp_publickey) return false;
    try { return (pk->cpp_publickey->is_on_device()); } catch (...) { return false; }
}

uint64_t* HEonGPU_CKKS_PublicKey_GetData(HE_CKKS_PublicKey* pk) {
    if (!pk || !pk->cpp_publickey) return 0;
    try {
        
        return reinterpret_cast<uint64_t*>(pk->cpp_publickey->data());
    } catch (...) { return 0; }
}

// Setter for PublicKey


// --- CKKS MultipartyPublicKey Functions ---

HE_CKKS_MultipartyPublicKey* HEonGPU_CKKS_MultipartyPublicKey_Create(HE_CKKS_Context* context, const C_RNGSeed_Const_Data* seed_c_data) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    if (!seed_c_data) return nullptr;

    try {
        heongpu::RNGSeed cpp_seed;
        if (seed_c_data->key_data && seed_c_data->key_len > 0) {
            cpp_seed.key_.assign(seed_c_data->key_data, seed_c_data->key_data + seed_c_data->key_len);
        }
        if (seed_c_data->nonce_data && seed_c_data->nonce_len > 0) {
            cpp_seed.nonce_.assign(seed_c_data->nonce_data, seed_c_data->nonce_data + seed_c_data->nonce_len);
        }
        if (seed_c_data->pstring_data && seed_c_data->pstring_len > 0) {
            cpp_seed.personalization_string_.assign(seed_c_data->pstring_data, seed_c_data->pstring_data + seed_c_data->pstring_len);
        }

        heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>* cpp_mp_pk_obj =
            new (std::nothrow) heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>(*cpp_h_context, cpp_seed);
        if (!cpp_mp_pk_obj) return nullptr;

        HE_CKKS_MultipartyPublicKey* c_api_mp_pk = new (std::nothrow) HE_CKKS_MultipartyPublicKey_s;
        if (!c_api_mp_pk) { delete cpp_mp_pk_obj; return nullptr; }
        c_api_mp_pk->cpp_mp_publickey = cpp_mp_pk_obj;
        return c_api_mp_pk;
    } catch (...) { return nullptr; }
}

void HEonGPU_CKKS_MultipartyPublicKey_Delete(HE_CKKS_MultipartyPublicKey* mp_pk) {
    if (mp_pk) {
        delete mp_pk->cpp_mp_publickey;
        delete mp_pk;
    }
}

HE_CKKS_MultipartyPublicKey* HEonGPU_CKKS_MultipartyPublicKey_Clone(const HE_CKKS_MultipartyPublicKey* other_mp_pk) {
    if (!other_mp_pk || !other_mp_pk->cpp_mp_publickey) return nullptr;
    try {
        auto cpp_clone = new (std::nothrow) heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>(*(other_mp_pk->cpp_mp_publickey));
        if (!cpp_clone) return nullptr;
        auto c_api_clone = new (std::nothrow) HE_CKKS_MultipartyPublicKey_s;
        if (!c_api_clone) { delete cpp_clone; return nullptr; }
        c_api_clone->cpp_mp_publickey = cpp_clone;
        return c_api_clone;
    } catch (...) { return nullptr; }
}

int HEonGPU_CKKS_MultipartyPublicKey_Assign_Copy(HE_CKKS_MultipartyPublicKey* dest_mp_pk, const HE_CKKS_MultipartyPublicKey* src_mp_pk) {
    if (!dest_mp_pk || !dest_mp_pk->cpp_mp_publickey || !src_mp_pk || !src_mp_pk->cpp_mp_publickey) return -1;
    try {
        *(dest_mp_pk->cpp_mp_publickey) = *(src_mp_pk->cpp_mp_publickey);
        return 0;
    } catch (...) { return -2; }
}

int HEonGPU_CKKS_MultipartyPublicKey_Save(HE_CKKS_MultipartyPublicKey* mp_pk, unsigned char** out_bytes, size_t* out_len) {
    if (!mp_pk || !mp_pk->cpp_mp_publickey || !out_bytes || !out_len) {
        if(out_bytes) *out_bytes = nullptr;
        if(out_len) *out_len = 0;
        return -1;
    }
    *out_bytes = nullptr; *out_len = 0;
    try {
        std::ostringstream oss(std::ios::binary);
        mp_pk->cpp_mp_publickey->save(oss); // MultipartyPublickey::save should handle base and seed
        std::string str_data = oss.str();
        *out_len = str_data.length();
        if (*out_len == 0) { *out_bytes = nullptr; return 0; }
        *out_bytes = static_cast<unsigned char*>(malloc(*out_len));
        if (!(*out_bytes)) { *out_len = 0; return -2; }
        std::memcpy(*out_bytes, str_data.data(), *out_len);
        return 0;
    } catch (...) { if(*out_bytes) {free(*out_bytes); *out_bytes = nullptr;} *out_len = 0; return -3; }
}

HE_CKKS_MultipartyPublicKey* HEonGPU_CKKS_MultipartyPublicKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, const C_RNGSeed_Const_Data* seed_for_reconstruction) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    if (!bytes && len > 0) return nullptr;

    // The C++ MultipartyPublickey::load might not need the seed explicitly if it's part of the serialized data.
    // However, its constructor needs a seed. If the seed IS part of the serialized data,
    // the load method handles it. If not, the C API user might need to provide it if load doesn't
    // restore it or if the object must be fully valid post-construction before load.
    // The current C++ MultipartyPublickey constructor requires a seed.
    // Let's assume for load, we construct with a temporary/default seed, then load populates it.
    // Or, the seed_for_reconstruction is used if the C++ load method doesn't restore the seed.
    // The C++ save/load in publickey.cu for MultipartyPublickey handles the seed.

    // TODO: Look more in depth to the load method/orion API to identify if this interpretation is correct.

    heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>* cpp_mp_pk = nullptr;
    HE_CKKS_MultipartyPublicKey* c_api_mp_pk = nullptr;
    try {
        // Default/dummy seed for initial construction before load
        heongpu::RNGSeed temp_seed; 
        if (seed_for_reconstruction && seed_for_reconstruction->key_data) { // Prefer provided seed if available
             if (seed_for_reconstruction->key_data && seed_for_reconstruction->key_len > 0) {
                temp_seed.key_.assign(seed_for_reconstruction->key_data, seed_for_reconstruction->key_data + seed_for_reconstruction->key_len);
            }
            if (seed_for_reconstruction->nonce_data && seed_for_reconstruction->nonce_len > 0) {
                temp_seed.nonce_.assign(seed_for_reconstruction->nonce_data, seed_for_reconstruction->nonce_data + seed_for_reconstruction->nonce_len);
            }
            if (seed_for_reconstruction->pstring_data && seed_for_reconstruction->pstring_len > 0) {
                temp_seed.personalization_string_.assign(seed_for_reconstruction->pstring_data, seed_for_reconstruction->pstring_data + seed_for_reconstruction->pstring_len);
            }
        }


        cpp_mp_pk = new (std::nothrow) heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>(*cpp_h_context, temp_seed);
        if (!cpp_mp_pk) return nullptr;

        if (len > 0 && bytes) {
            std::string str_data(reinterpret_cast<const char*>(bytes), len);
            std::istringstream iss(str_data, std::ios::binary);
            cpp_mp_pk->load(iss); // This should load base class data AND the seed
        }
        
        c_api_mp_pk = new (std::nothrow) HE_CKKS_MultipartyPublicKey_s;
        if (!c_api_mp_pk) { delete cpp_mp_pk; return nullptr; }
        c_api_mp_pk->cpp_mp_publickey = cpp_mp_pk;
        return c_api_mp_pk;
    } catch (...) { delete cpp_mp_pk; delete c_api_mp_pk; return nullptr; }
}





} // extern "C"