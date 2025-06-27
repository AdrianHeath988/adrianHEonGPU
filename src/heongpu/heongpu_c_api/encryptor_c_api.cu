#include "encryptor_c_api.h"
#include "heongpu.cuh"
#include "heongpu_c_api_internal.h"
#include "ckks/context.cuh"
#include "ckks/publickey.cuh"
#include "ckks/secretkey.cuh"
#include "ckks/plaintext.cuh"
#include "ckks/ciphertext.cuh"
#include "ckks/encryptor.cuh" // The C++ class we are wrapping

#include "storagemanager.cuh" // For heongpu::ExecutionOptions

#include <vector>
#include <iostream> // For error logging
#include <new>      // For std::nothrow

// Define the opaque struct


typedef struct HE_CKKS_Encryptor_s HE_CKKS_Encryptor;

// Helper to safely access underlying C++ pointers from opaque C pointers
static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context_enc(HE_CKKS_Context* context) {
    if (!context || !context->cpp_context) return nullptr; // Assuming cpp_context from context_c_api.cu
    return context->cpp_context;
}
static heongpu::Publickey<heongpu::Scheme::CKKS>* get_cpp_publickey_enc(HE_CKKS_PublicKey* pk) {
    if (!pk || !pk->cpp_publickey) return nullptr; // Assuming cpp_publickey from publickey_c_api.cu
    return pk->cpp_publickey;
}
static heongpu::Secretkey<heongpu::Scheme::CKKS>* get_cpp_secretkey_enc(HE_CKKS_SecretKey* sk) {
    if (!sk || !sk->cpp_secretkey) return nullptr; // Assuming cpp_secretkey from secretkey_c_api.cu
    return sk->cpp_secretkey;
}
static heongpu::Plaintext<heongpu::Scheme::CKKS>* get_cpp_plaintext_enc(HE_CKKS_Plaintext* pt) {
    if (!pt || !pt->cpp_plaintext) return nullptr; // Assuming cpp_plaintext from plaintext_c_api.cu
    return pt->cpp_plaintext;
}
static heongpu::Ciphertext<heongpu::Scheme::CKKS>* get_cpp_ciphertext_enc(HE_CKKS_Ciphertext* ct) {
    if (!ct || !ct->cpp_ciphertext) return nullptr; // Assuming cpp_ciphertext from ciphertext_c_api.cu
    return ct->cpp_ciphertext;
}

// Helper to map C types to C++ ExecutionOptions
static heongpu::ExecutionOptions map_c_to_cpp_execution_options_enc(const C_ExecutionOptions* c_options) {
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

// --- CKKS HEEncryptor Lifecycle ---

HE_CKKS_Encryptor* HEonGPU_CKKS_Encryptor_Create_With_PublicKey(HE_CKKS_Context* context,
                                                                HE_CKKS_PublicKey* pk) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context_enc(context);
    heongpu::Publickey<heongpu::Scheme::CKKS>* cpp_pk = get_cpp_publickey_enc(pk);
    if (!cpp_h_context || !cpp_pk) {
        std::cerr << "Encryptor_Create_With_PublicKey: Invalid context or public key." << std::endl;
        return nullptr;
    }
    try {
        auto cpp_obj = new (std::nothrow) heongpu::HEEncryptor<heongpu::Scheme::CKKS>(*cpp_h_context, *cpp_pk);
        if (!cpp_obj) { std::cerr << "Encryptor_Create_With_PublicKey: C++ allocation failed.\n"; return nullptr; }
        auto c_api_obj = new (std::nothrow) HE_CKKS_Encryptor_s;
        if (!c_api_obj) { delete cpp_obj; std::cerr << "Encryptor_Create_With_PublicKey: C API wrapper allocation failed.\n"; return nullptr; }
        c_api_obj->cpp_encryptor = cpp_obj;
        return c_api_obj;
    } catch (const std::exception& e) { std::cerr << "Encryptor_Create_With_PublicKey Error: " << e.what() << std::endl; return nullptr; }
      catch (...) { std::cerr << "Encryptor_Create_With_PublicKey Unknown Error" << std::endl; return nullptr; }
}

// HE_CKKS_Encryptor* HEonGPU_CKKS_Encryptor_Create_With_SecretKey(HE_CKKS_Context* context,
//                                                                 HE_CKKS_SecretKey* sk) {
//     heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context_enc(context);
//     heongpu::Secretkey<heongpu::Scheme::CKKS>* cpp_sk = get_cpp_secretkey_enc(sk);
//     if (!cpp_h_context || !cpp_sk) {
//         std::cerr << "Encryptor_Create_With_SecretKey: Invalid context or secret key." << std::endl;
//         return nullptr;
//     }
//     try {
//         auto cpp_obj = new (std::nothrow) heongpu::HEEncryptor<heongpu::Scheme::CKKS>(*cpp_h_context, *cpp_sk);
//         if (!cpp_obj) { std::cerr << "Encryptor_Create_With_SecretKey: C++ allocation failed.\n"; return nullptr; }
//         auto c_api_obj = new (std::nothrow) HE_CKKS_Encryptor_s;
//         if (!c_api_obj) { delete cpp_obj; std::cerr << "Encryptor_Create_With_SecretKey: C API wrapper allocation failed.\n"; return nullptr; }
//         c_api_obj->cpp_encryptor = cpp_obj;
//         return c_api_obj;
//     } catch (const std::exception& e) { std::cerr << "Encryptor_Create_With_SecretKey Error: " << e.what() << std::endl; return nullptr; }
//       catch (...) { std::cerr << "Encryptor_Create_With_SecretKey Unknown Error" << std::endl; return nullptr; }
// }

void HEonGPU_CKKS_Encryptor_Delete(HE_CKKS_Encryptor* encryptor) {
    if (encryptor) {
        delete encryptor->cpp_encryptor;
        delete encryptor;
    }
}

// --- CKKS Encryption Functions ---

int HEonGPU_CKKS_Encryptor_Encrypt_To(HE_CKKS_Encryptor* encryptor,
                                      HE_CKKS_Ciphertext* ct_out_c,
                                      HE_CKKS_Plaintext* pt_in_c,
                                      const C_ExecutionOptions* options_c) {
    if (!encryptor || !encryptor->cpp_encryptor || !ct_out_c || !get_cpp_ciphertext_enc(ct_out_c) || !pt_in_c || !get_cpp_plaintext_enc(pt_in_c)) {
        std::cerr << "Encrypt_To: Invalid argument(s).\n"; return -1;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_enc(options_c);
        encryptor->cpp_encryptor->encrypt(*(get_cpp_ciphertext_enc(ct_out_c)), *(get_cpp_plaintext_enc(pt_in_c)), cpp_options);
        return 0; // Success
    } catch (const std::exception& e) { std::cerr << "Encrypt_To Error: " << e.what() << std::endl; return -2; }
      catch (...) { std::cerr << "Encrypt_To Unknown Error" << std::endl; return -2; }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_Encryptor_Encrypt_New(HE_CKKS_Encryptor* encryptor,
                                                       HE_CKKS_Plaintext* pt_in_c,
                                                       const C_ExecutionOptions* options_c) {
    if (!encryptor || !encryptor->cpp_encryptor || !pt_in_c || !get_cpp_plaintext_enc(pt_in_c)) {
        std::cerr << "Encrypt_New: Invalid argument(s).\n"; return nullptr;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_enc(options_c);
        heongpu::Ciphertext<heongpu::Scheme::CKKS> cpp_result_ct;
        heongpu::Plaintext<heongpu::Scheme::CKKS> cpp_plaintext = *(get_cpp_plaintext_enc(pt_in_c));
        encryptor->cpp_encryptor->encrypt(cpp_result_ct, cpp_plaintext, cpp_options);

        auto cpp_heap_result = new (std::nothrow) heongpu::Ciphertext<heongpu::Scheme::CKKS>(std::move(cpp_result_ct));
        if (!cpp_heap_result) { std::cerr << "Encrypt_New: C++ result allocation failed.\n"; return nullptr; }

        HE_CKKS_Ciphertext* c_api_result = new (std::nothrow) HE_CKKS_Ciphertext_s;
        if (!c_api_result) { delete cpp_heap_result; std::cerr << "Encrypt_New: C API wrapper allocation failed.\n"; return nullptr; }
        
        c_api_result->cpp_ciphertext = cpp_heap_result; // Assuming cpp_ciphertext member in HE_CKKS_Ciphertext_s
        return c_api_result;
    } catch (const std::exception& e) { std::cerr << "Encrypt_New Error: " << e.what() << std::endl; return nullptr; }
      catch (...) { std::cerr << "Encrypt_New Unknown Error" << std::endl; return nullptr; }
}

// --- CKKS Encryptor Seed/Offset Management ---

int HEonGPU_CKKS_Encryptor_GetSeed(HE_CKKS_Encryptor* encryptor) {
    if (!encryptor || !encryptor->cpp_encryptor) {
        std::cerr << "GetSeed: Invalid encryptor pointer.\n"; return -1; // Or some other error indicator
    }
    try {
        return encryptor->cpp_encryptor->get_seed();
    } catch (...) { return -1; } // Should not throw if getter is noexcept
}

void HEonGPU_CKKS_Encryptor_SetSeed(HE_CKKS_Encryptor* encryptor, int new_seed) {
    if (!encryptor || !encryptor->cpp_encryptor) {
        std::cerr << "SetSeed: Invalid encryptor pointer.\n"; return;
    }
    try {
        encryptor->cpp_encryptor->set_seed(new_seed);
    } catch (const std::exception& e) { std::cerr << "SetSeed Error: " << e.what() << std::endl;}
      catch (...) { std::cerr << "SetSeed Unknown Error" << std::endl;}
}

int HEonGPU_CKKS_Encryptor_GetOffset(HE_CKKS_Encryptor* encryptor) {
    if (!encryptor || !encryptor->cpp_encryptor) {
        std::cerr << "GetOffset: Invalid encryptor pointer.\n"; return -1; // Or some other error indicator
    }
    try {
        return encryptor->cpp_encryptor->get_offset();
    } catch (...) { return -1; }
}

void HEonGPU_CKKS_Encryptor_SetOffset(HE_CKKS_Encryptor* encryptor, int new_offset) {
    if (!encryptor || !encryptor->cpp_encryptor) {
        std::cerr << "SetOffset: Invalid encryptor pointer.\n"; return;
    }
    try {
        encryptor->cpp_encryptor->set_offset(new_offset);
    } catch (const std::exception& e) { std::cerr << "SetOffset Error: " << e.what() << std::endl;}
      catch (...) { std::cerr << "SetOffset Unknown Error" << std::endl;}
}

} // extern "C"