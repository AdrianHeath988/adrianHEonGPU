#include "keygenerator_c_api.h"
#include "heongpu.cuh"

#include "ckks/context.cuh"
#include "ckks/secretkey.cuh"
#include "ckks/publickey.cuh"
#include "ckks/evaluationkey.cuh"
#include "ckks/keygenerator.cuh" // The C++ class we are wrapping

#include "random.cuh"         // For heongpu::RNGSeed
#include "storagemanager.cuh" // For heongpu::ExecutionOptions

#include <vector>
#include <iostream> // For error logging
#include <new>      // For std::nothrow

// Define the opaque struct
typedef struct HE_CKKS_KeyGenerator_s HE_CKKS_KeyGenerator;
// Helper to safely access underlying C++ pointers from opaque C pointers
static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context_kg(HE_CKKS_Context* context) {
    if (!context || !context->cpp_context) return nullptr;
    return context->cpp_context;
}
static heongpu::SecretKey<heongpu::Scheme::CKKS>* get_cpp_secretkey(HE_CKKS_SecretKey* sk) {
    if (!sk || !sk->cpp_secretkey) return nullptr;
    return sk->cpp_secretkey;
}
static const heongpu::SecretKey<heongpu::Scheme::CKKS>* get_const_cpp_secretkey(const HE_CKKS_SecretKey* sk) {
    if (!sk || !sk->cpp_secretkey) return nullptr;
    return sk->cpp_secretkey;
}
static heongpu::Publickey<heongpu::Scheme::CKKS>* get_cpp_publickey(HE_CKKS_PublicKey* pk) {
    if (!pk || !pk->cpp_publickey) return nullptr;
    return pk->cpp_publickey;
}
static heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>* get_cpp_mp_publickey(HE_CKKS_MultipartyPublicKey* mp_pk) {
    if (!mp_pk || !mp_pk->cpp_mp_publickey) return nullptr;
    return mp_pk->cpp_mp_publickey;
}
static const heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>* get_const_cpp_mp_publickey(const HE_CKKS_MultipartyPublicKey* mp_pk) {
    if (!mp_pk || !mp_pk->cpp_mp_publickey) return nullptr;
    return mp_pk->cpp_mp_publickey;
}
static heongpu::Relinkey<heongpu::Scheme::CKKS>* get_cpp_relinkey(HE_CKKS_RelinKey* rlk) {
    if (!rlk || !rlk->cpp_relinkey) return nullptr;
    return rlk->cpp_relinkey;
}
static heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>* get_cpp_mp_relinkey(HE_CKKS_MultipartyRelinKey* mp_rlk) {
    if (!mp_rlk || !mp_rlk->cpp_mp_relinkey) return nullptr;
    return mp_rlk->cpp_mp_relinkey;
}
static const heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>* get_const_cpp_mp_relinkey(const HE_CKKS_MultipartyRelinKey* mp_rlk) {
    if (!mp_rlk || !mp_rlk->cpp_mp_relinkey) return nullptr;
    return mp_rlk->cpp_mp_relinkey;
}
static heongpu::Galoiskey<heongpu::Scheme::CKKS>* get_cpp_galoiskey(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return nullptr;
    return gk->cpp_galoiskey;
}
static const heongpu::Galoiskey<heongpu::Scheme::CKKS>* get_const_cpp_galoiskey(const HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return nullptr;
    return gk->cpp_galoiskey;
}

// Helper to map C types to C++ ExecutionOptions
static heongpu::ExecutionOptions map_c_to_cpp_execution_options_kg(const C_ExecutionOptions* c_options) {
    heongpu::ExecutionOptions cpp_options; // Defaults from C++ struct definition
    if (c_options) {
        cpp_options.stream_ = static_cast<cudaStream_t>(c_options->stream);
        if (c_options->storage == C_STORAGE_TYPE_HOST) {
            cpp_options.storage_ = heongpu::storage_type::HOST;
        } else if (c_options->storage == C_STORAGE_TYPE_DEVICE) {
            cpp_options.storage_ = heongpu::storage_type::DEVICE;
        }
        cpp_options.keep_initial_condition_ = c_options->keep_initial_condition;
    }
    return cpp_options;
}


extern "C" {

// --- CKKS HEKeyGenerator Lifecycle ---
HE_CKKS_KeyGenerator* HEonGPU_CKKS_KeyGenerator_Create(HE_CKKS_Context* context) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context_kg(context);
    if (!cpp_h_context) {
        std::cerr << "KeyGenerator_Create failed: Invalid context." << std::endl;
        return nullptr;
    }
    try {
        auto cpp_obj = new (std::nothrow) heongpu::HEKeyGenerator<heongpu::Scheme::CKKS>(*cpp_h_context);
        if (!cpp_obj) { std::cerr << "KeyGenerator_Create: C++ allocation failed.\n"; return nullptr; }
        auto c_api_obj = new (std::nothrow) HE_CKKS_KeyGenerator_s;
        if (!c_api_obj) { delete cpp_obj; std::cerr << "KeyGenerator_Create: C API wrapper allocation failed.\n"; return nullptr; }
        c_api_obj->cpp_keygen = cpp_obj;
        return c_api_obj;
    } catch (const std::exception& e) { std::cerr << "KeyGenerator_Create Error: " << e.what() << std::endl; return nullptr; }
      catch (...) { std::cerr << "KeyGenerator_Create Unknown Error" << std::endl; return nullptr; }
}

void HEonGPU_CKKS_KeyGenerator_Delete(HE_CKKS_KeyGenerator* kg) {
    if (kg) { delete kg->cpp_keygen; delete kg; }
}

// --- Seed Configuration ---
void HEonGPU_CKKS_KeyGenerator_SetSeed(HE_CKKS_KeyGenerator* kg, const C_RNGSeed_Const_Data* seed_c) {
    if (!kg || !kg->cpp_keygen || !seed_c) {
        std::cerr << "KeyGenerator_SetSeed: Invalid argument(s).\n"; return;
    }
    try {
        heongpu::RNGSeed cpp_seed;
        if (seed_c->key_data && seed_c->key_len > 0) {
            cpp_seed.key_.assign(seed_c->key_data, seed_c->key_data + seed_c->key_len);
        }
        if (seed_c->nonce_data && seed_c->nonce_len > 0) {
            cpp_seed.nonce_.assign(seed_c->nonce_data, seed_c->nonce_data + seed_c->nonce_len);
        }
        if (seed_c->pstring_data && seed_c->pstring_len > 0) {
            cpp_seed.personalization_string_.assign(seed_c->pstring_data, seed_c->pstring_data + seed_c->pstring_len);
        }
        kg->cpp_keygen->set_seed(cpp_seed);
    } catch (const std::exception& e) { std::cerr << "KeyGenerator_SetSeed Error: " << e.what() << std::endl; }
      catch (...) { std::cerr << "KeyGenerator_SetSeed Unknown Error" << std::endl; }
}

// --- Standard Key Generation ---
#define WRAP_STD_KEYGEN_FUNC(FuncName, CppKeyType, CKeyType, GetCppKeyFunc) \
int FuncName(HE_CKKS_KeyGenerator* kg, CKeyType* key_out_c, const HE_CKKS_SecretKey* sk_c, const C_ExecutionOptions* options_c) { \
    if (!kg || !kg->cpp_keygen || !key_out_c || !GetCppKeyFunc(key_out_c) || !get_const_cpp_secretkey(sk_c)) { \
        std::cerr << #FuncName " Error: Invalid argument(s).\n"; return -1; \
    } \
    try { \
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_kg(options_c); \
        kg->cpp_keygen->CppKeyType(*(GetCppKeyFunc(key_out_c)), *(get_const_cpp_secretkey(sk_c)), cpp_options); \
        return 0; \
    } catch (const std::exception& e) { std::cerr << #FuncName " Error: " << e.what() << std::endl; return -2; } \
      catch (...) { std::cerr << #FuncName " Unknown Error" << std::endl; return -2; } \
}

int HEonGPU_CKKS_KeyGenerator_GenerateSecretKey(HE_CKKS_KeyGenerator* kg, HE_CKKS_SecretKey* sk_c, int hamming_weight, const C_ExecutionOptions* options_c) {
    if (!kg || !kg->cpp_keygen || !sk_c || !get_cpp_secretkey(sk_c)) {
        std::cerr << "GenerateSecretKey Error: Invalid argument(s).\n"; return -1;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_kg(options_c);
        kg->cpp_keygen->generate_secret_key(*(get_cpp_secretkey(sk_c)), hamming_weight, cpp_options);
        return 0;
    } catch (const std::exception& e) { std::cerr << "GenerateSecretKey Error: " << e.what() << std::endl; return -2; }
      catch (...) { std::cerr << "GenerateSecretKey Unknown Error" << std::endl; return -2; }
}

WRAP_STD_KEYGEN_FUNC(HEonGPU_CKKS_KeyGenerator_GeneratePublicKey, generate_public_key, HE_CKKS_PublicKey, get_cpp_publickey)
WRAP_STD_KEYGEN_FUNC(HEonGPU_CKKS_KeyGenerator_GenerateRelinKey, generate_relinkey, HE_CKKS_RelinKey, get_cpp_relinkey)
WRAP_STD_KEYGEN_FUNC(HEonGPU_CKKS_KeyGenerator_GenerateGaloisKey, generate_galoiskey, HE_CKKS_GaloisKey, get_cpp_galoiskey)


// --- Multiparty Key Generation ---
#define WRAP_MP_KEYGEN_FUNC(FuncName, CppFuncName, CppKeyType, CKeyType, GetCppKeyFunc) \
int FuncName(HE_CKKS_KeyGenerator* kg, CKeyType* key_out_c, const HE_CKKS_SecretKey* sk_c, const C_ExecutionOptions* options_c) { \
    if (!kg || !kg->cpp_keygen || !key_out_c || !GetCppKeyFunc(key_out_c) || !get_const_cpp_secretkey(sk_c)) { \
        std::cerr << #FuncName " Error: Invalid argument(s).\n"; return -1; \
    } \
    try { \
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_kg(options_c); \
        kg->cpp_keygen->CppFuncName(*(GetCppKeyFunc(key_out_c)), *(get_const_cpp_secretkey(sk_c)), cpp_options); \
        return 0; \
    } catch (const std::exception& e) { std::cerr << #FuncName " Error: " << e.what() << std::endl; return -2; } \
      catch (...) { std::cerr << #FuncName " Unknown Error" << std::endl; return -2; } \
}

WRAP_MP_KEYGEN_FUNC(HEonGPU_CKKS_KeyGenerator_GenerateMultipartyPublicKey, generate_multiparty_public_key, heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>, HE_CKKS_MultipartyPublicKey, get_cpp_mp_publickey)
WRAP_MP_KEYGEN_FUNC(HEonGPU_CKKS_KeyGenerator_GenerateMultipartyRelinKey, generate_multiparty_relinkey, heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>, HE_CKKS_MultipartyRelinKey, get_cpp_mp_relinkey)
WRAP_MP_KEYGEN_FUNC(HEonGPU_CKKS_KeyGenerator_GenerateMultipartyGaloisKey, generate_multiparty_galoiskey, heongpu::Galoiskey<heongpu::Scheme::CKKS>, HE_CKKS_GaloisKey, get_cpp_galoiskey) /* C++ uses Galoiskey here */


// --- Multiparty Key Aggregation ---
int HEonGPU_CKKS_KeyGenerator_AggregateMultipartyPublicKey(HE_CKKS_KeyGenerator* kg, const HE_CKKS_MultipartyPublicKey* const* public_keys_array_c, size_t num_public_keys, HE_CKKS_PublicKey* aggregated_pk_c, const C_ExecutionOptions* options_c) {
    if (!kg || !kg->cpp_keygen || (num_public_keys > 0 && !public_keys_array_c) || !aggregated_pk_c || !get_cpp_publickey(aggregated_pk_c)) {
        std::cerr << "AggregateMultipartyPublicKey Error: Invalid argument(s).\n"; return -1;
    }
    try {
        std::vector<heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>> cpp_pk_vec;
        cpp_pk_vec.reserve(num_public_keys);
        for (size_t i = 0; i < num_public_keys; ++i) {
            const heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>* cpp_mp_pk = get_const_cpp_mp_publickey(public_keys_array_c[i]);
            if (!cpp_mp_pk) { std::cerr << "AggregateMultipartyPublicKey Error: Null key in array at index " << i << std::endl; return -1; }
            cpp_pk_vec.push_back(*cpp_mp_pk); // Makes a copy, C++ method takes vector of objects
        }
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_kg(options_c);
        kg->cpp_keygen->aggregate_multiparty_public_key(cpp_pk_vec, *(get_cpp_publickey(aggregated_pk_c)), cpp_options);
        return 0;
    } catch (const std::exception& e) { std::cerr << "AggregateMultipartyPublicKey Error: " << e.what() << std::endl; return -2; }
      catch (...) { std::cerr << "AggregateMultipartyPublicKey Unknown Error" << std::endl; return -2; }
}


int HEonGPU_CKKS_KeyGenerator_AggregateMultipartyRelinKey(HE_CKKS_KeyGenerator* kg, const HE_CKKS_MultipartyRelinKey* const* relin_keys_array_c, size_t num_relin_keys, HE_CKKS_RelinKey* aggregated_rlk_c, const C_ExecutionOptions* options_c) {
    if (!kg || !kg->cpp_keygen || (num_relin_keys > 0 && !relin_keys_array_c) || !aggregated_rlk_c || !get_cpp_relinkey(aggregated_rlk_c)) {
         std::cerr << "AggregateMultipartyRelinKey Error: Invalid argument(s).\n"; return -1;
    }
    try {
        std::vector<heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>> cpp_rlk_vec;
        cpp_rlk_vec.reserve(num_relin_keys);
        for (size_t i = 0; i < num_relin_keys; ++i) {
             const heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>* cpp_mp_rlk = get_const_cpp_mp_relinkey(relin_keys_array_c[i]);
             if (!cpp_mp_rlk) { std::cerr << "AggregateMultipartyRelinKey Error: Null key in array at index " << i << std::endl; return -1; }
            cpp_rlk_vec.push_back(*cpp_mp_rlk);
        }
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_kg(options_c);
        kg->cpp_keygen->aggregate_multiparty_relinkey(cpp_rlk_vec, *(get_cpp_relinkey(aggregated_rlk_c)), cpp_options);
        return 0;
    } catch (const std::exception& e) { std::cerr << "AggregateMultipartyRelinKey Error: " << e.what() << std::endl; return -2; }
      catch (...) { std::cerr << "AggregateMultipartyRelinKey Unknown Error" << std::endl; return -2; }
}

int HEonGPU_CKKS_KeyGenerator_AggregateMultipartyGaloisKey(HE_CKKS_KeyGenerator* kg, const HE_CKKS_GaloisKey* const* galois_keys_array_c, size_t num_galois_keys, HE_CKKS_GaloisKey* aggregated_gk_c, const C_ExecutionOptions* options_c) {
    if (!kg || !kg->cpp_keygen || (num_galois_keys > 0 && !galois_keys_array_c) || !aggregated_gk_c || !get_cpp_galoiskey(aggregated_gk_c) ) {
        std::cerr << "AggregateMultipartyGaloisKey Error: Invalid argument(s).\n"; return -1;
    }
    try {
        std::vector<heongpu::Galoiskey<heongpu::Scheme::CKKS>> cpp_gk_vec; // C++ takes vector of Galoiskey
        cpp_gk_vec.reserve(num_galois_keys);
        for (size_t i = 0; i < num_galois_keys; ++i) {
            const heongpu::Galoiskey<heongpu::Scheme::CKKS>* cpp_gk = get_const_cpp_galoiskey(galois_keys_array_c[i]);
            if (!cpp_gk) { std::cerr << "AggregateMultipartyGaloisKey Error: Null key in array at index " << i << std::endl; return -1; }
            cpp_gk_vec.push_back(*cpp_gk);
        }
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_kg(options_c);
        kg->cpp_keygen->aggregate_multiparty_galoiskey(cpp_gk_vec, *(get_cpp_galoiskey(aggregated_gk_c)), cpp_options);
        return 0;
    } catch (const std::exception& e) { std::cerr << "AggregateMultipartyGaloisKey Error: " << e.what() << std::endl; return -2; }
      catch (...) { std::cerr << "AggregateMultipartyGaloisKey Unknown Error" << std::endl; return -2; }
}

} // extern "C"