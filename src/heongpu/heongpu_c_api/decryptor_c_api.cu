#include "decryptor_c_api.h"
#include "heongpu.cuh"

#include "ckks/context.cuh"
#include "ckks/secretkey.cuh"
#include "ckks/plaintext.cuh"
#include "ckks/ciphertext.cuh"
#include "ckks/decryptor.cuh" // The C++ class we are wrapping

#include "util/storagemanager.cuh" // For heongpu::ExecutionOptions

#include <vector>
#include <iostream> // For error logging
#include <new>      // For std::nothrow

// Define the opaque struct
struct HE_CKKS_Decryptor_s {
    heongpu::HEDecryptor<heongpu::Scheme::CKKS>* cpp_decryptor;
};

// Helper to safely access underlying C++ pointers from opaque C pointers
static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context_dec(HE_CKKS_Context* context) {
    if (!context || !context->cpp_context) return nullptr; // Assuming cpp_context from context_c_api.cu
    return context->cpp_context;
}
static heongpu::SecretKey<heongpu::Scheme::CKKS>* get_cpp_secretkey_dec(HE_CKKS_SecretKey* sk) {
    if (!sk || !sk->cpp_secretkey) return nullptr; // Assuming cpp_secretkey from secretkey_c_api.cu
    return sk->cpp_secretkey;
}
static heongpu::Plaintext<heongpu::Scheme::CKKS>* get_cpp_plaintext_dec(HE_CKKS_Plaintext* pt) {
    if (!pt || !pt->cpp_plaintext) return nullptr; // Assuming cpp_plaintext from plaintext_c_api.cu
    return pt->cpp_plaintext;
}
static heongpu::Ciphertext<heongpu::Scheme::CKKS>* get_cpp_ciphertext_dec(HE_CKKS_Ciphertext* ct) {
    if (!ct || !ct->cpp_ciphertext) return nullptr; // Assuming cpp_ciphertext from ciphertext_c_api.cu
    return ct->cpp_ciphertext;
}
static const heongpu::Ciphertext<heongpu::Scheme::CKKS>* get_const_cpp_ciphertext_dec(const HE_CKKS_Ciphertext* ct) {
    if (!ct || !ct->cpp_ciphertext) return nullptr;
    return ct->cpp_ciphertext;
}


// Helper to map C types to C++ ExecutionOptions
static heongpu::ExecutionOptions map_c_to_cpp_execution_options_dec(const C_ExecutionOptions* c_options) {
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

// --- CKKS HEDecryptor Lifecycle ---

HE_CKKS_Decryptor* HEonGPU_CKKS_Decryptor_Create(HE_CKKS_Context* context, HE_CKKS_SecretKey* sk) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context_dec(context);
    heongpu::SecretKey<heongpu::Scheme::CKKS>* cpp_sk = get_cpp_secretkey_dec(sk);
    if (!cpp_h_context || !cpp_sk) {
        std::cerr << "Decryptor_Create: Invalid context or secret key." << std::endl;
        return nullptr;
    }
    try {
        auto cpp_obj = new (std::nothrow) heongpu::HEDecryptor<heongpu::Scheme::CKKS>(*cpp_h_context, *cpp_sk);
        if (!cpp_obj) { std::cerr << "Decryptor_Create: C++ allocation failed.\n"; return nullptr; }
        auto c_api_obj = new (std::nothrow) HE_CKKS_Decryptor_s;
        if (!c_api_obj) { delete cpp_obj; std::cerr << "Decryptor_Create: C API wrapper allocation failed.\n"; return nullptr; }
        c_api_obj->cpp_decryptor = cpp_obj;
        return c_api_obj;
    } catch (const std::exception& e) { std::cerr << "Decryptor_Create Error: " << e.what() << std::endl; return nullptr; }
      catch (...) { std::cerr << "Decryptor_Create Unknown Error" << std::endl; return nullptr; }
}

void HEonGPU_CKKS_Decryptor_Delete(HE_CKKS_Decryptor* decryptor) {
    if (decryptor) {
        delete decryptor->cpp_decryptor;
        delete decryptor;
    }
}

// --- CKKS Decryption Functions ---

int HEonGPU_CKKS_Decryptor_Decrypt(HE_CKKS_Decryptor* decryptor,
                                   HE_CKKS_Plaintext* pt_out_c,
                                   HE_CKKS_Ciphertext* ct_in_c,
                                   const C_ExecutionOptions* options_c) {
    if (!decryptor || !decryptor->cpp_decryptor || !pt_out_c || !get_cpp_plaintext_dec(pt_out_c) || !ct_in_c || !get_cpp_ciphertext_dec(ct_in_c)) {
        std::cerr << "Decrypt: Invalid argument(s).\n"; return -1;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_dec(options_c);
        decryptor->cpp_decryptor->decrypt(*(get_cpp_plaintext_dec(pt_out_c)), *(get_cpp_ciphertext_dec(ct_in_c)), cpp_options);
        return 0; // Success
    } catch (const std::exception& e) { std::cerr << "Decrypt Error: " << e.what() << std::endl; return -2; }
      catch (...) { std::cerr << "Decrypt Unknown Error" << std::endl; return -2; }
}

// --- Noise Budget Calculation ---

double HEonGPU_CKKS_Decryptor_CalculateNoiseBudget(HE_CKKS_Decryptor* decryptor,
                                                   HE_CKKS_Ciphertext* ct_c,
                                                   const C_ExecutionOptions* options_c) {
    if (!decryptor || !decryptor->cpp_decryptor || !ct_c || !get_cpp_ciphertext_dec(ct_c)) {
        std::cerr << "CalculateNoiseBudget: Invalid argument(s).\n"; return -1.0; // Error indicator
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_dec(options_c);
        return decryptor->cpp_decryptor->calculate_noise_budget(*(get_cpp_ciphertext_dec(ct_c)), cpp_options);
    } catch (const std::exception& e) { std::cerr << "CalculateNoiseBudget Error: " << e.what() << std::endl; return -1.0; }
      catch (...) { std::cerr << "CalculateNoiseBudget Unknown Error" << std::endl; return -1.0; }
}

// --- Multiparty Decryption Functions ---

int HEonGPU_CKKS_Decryptor_PartialDecrypt(HE_CKKS_Decryptor* decryptor,
                                          HE_CKKS_Plaintext* partial_pt_out_c,
                                          HE_CKKS_Ciphertext* ct_in_c,
                                          C_cudaStream_t stream_c) {
    if (!decryptor || !decryptor->cpp_decryptor || !partial_pt_out_c || !get_cpp_plaintext_dec(partial_pt_out_c) || !ct_in_c || !get_cpp_ciphertext_dec(ct_in_c)) {
        std::cerr << "PartialDecrypt: Invalid argument(s).\n"; return -1;
    }
    try {
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream_c);
        decryptor->cpp_decryptor->partial_decrypt(*(get_cpp_plaintext_dec(partial_pt_out_c)), *(get_cpp_ciphertext_dec(ct_in_c)), cpp_stream);
        return 0; // Success
    } catch (const std::exception& e) { std::cerr << "PartialDecrypt Error: " << e.what() << std::endl; return -2; }
      catch (...) { std::cerr << "PartialDecrypt Unknown Error" << std::endl; return -2; }
}

int HEonGPU_CKKS_Decryptor_DecryptFusion(HE_CKKS_Decryptor* decryptor,
                                         const HE_CKKS_Ciphertext* const* partial_cts_array_c,
                                         size_t num_partial_cts,
                                         HE_CKKS_Plaintext* final_pt_out_c,
                                         C_cudaStream_t stream_c) {
    if (!decryptor || !decryptor->cpp_decryptor || (num_partial_cts > 0 && !partial_cts_array_c) || !final_pt_out_c || !get_cpp_plaintext_dec(final_pt_out_c)) {
        std::cerr << "DecryptFusion: Invalid argument(s).\n"; return -1;
    }
    try {
        std::vector<heongpu::Ciphertext<heongpu::Scheme::CKKS>> cpp_partial_cts_vec;
        cpp_partial_cts_vec.reserve(num_partial_cts);
        for (size_t i = 0; i < num_partial_cts; ++i) {
            const heongpu::Ciphertext<heongpu::Scheme::CKKS>* cpp_ct = get_const_cpp_ciphertext_dec(partial_cts_array_c[i]);
            if (!cpp_ct) {
                std::cerr << "DecryptFusion Error: Null ciphertext in array at index " << i << std::endl; return -1;
            }
            cpp_partial_cts_vec.push_back(*cpp_ct); // Makes a copy for the vector
        }
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream_c);
        decryptor->cpp_decryptor->decrypt_fusion_ckks(cpp_partial_cts_vec, *(get_cpp_plaintext_dec(final_pt_out_c)), cpp_stream);
        return 0; // Success
    } catch (const std::exception& e) { std::cerr << "DecryptFusion Error: " << e.what() << std::endl; return -2; }
      catch (...) { std::cerr << "DecryptFusion Unknown Error" << std::endl; return -2; }
}

// --- CKKS Decryptor Seed/Offset Management ---
// These are identical to Encryptor's; good candidates for a shared utility if more PRNGs were wrapped

int HEonGPU_CKKS_Decryptor_GetSeed(HE_CKKS_Decryptor* decryptor) {
    if (!decryptor || !decryptor->cpp_decryptor) {
        std::cerr << "GetSeed: Invalid decryptor pointer.\n"; return -1; 
    }
    try { return decryptor->cpp_decryptor->get_seed(); } 
    catch (...) { return -1; }
}

void HEonGPU_CKKS_Decryptor_SetSeed(HE_CKKS_Decryptor* decryptor, int new_seed) {
    if (!decryptor || !decryptor->cpp_decryptor) {
        std::cerr << "SetSeed: Invalid decryptor pointer.\n"; return;
    }
    try { decryptor->cpp_decryptor->set_seed(new_seed); } 
    catch (const std::exception& e) { std::cerr << "SetSeed Error: " << e.what() << std::endl;}
    catch (...) { std::cerr << "SetSeed Unknown Error" << std::endl;}
}

int HEonGPU_CKKS_Decryptor_GetOffset(HE_CKKS_Decryptor* decryptor) {
    if (!decryptor || !decryptor->cpp_decryptor) {
        std::cerr << "GetOffset: Invalid decryptor pointer.\n"; return -1; 
    }
    try { return decryptor->cpp_decryptor->get_offset(); } 
    catch (...) { return -1; }
}

void HEonGPU_CKKS_Decryptor_SetOffset(HE_CKKS_Decryptor* decryptor, int new_offset) {
    if (!decryptor || !decryptor->cpp_decryptor) {
        std::cerr << "SetOffset: Invalid decryptor pointer.\n"; return;
    }
    try { decryptor->cpp_decryptor->set_offset(new_offset); } 
    catch (const std::exception& e) { std::cerr << "SetOffset Error: " << e.what() << std::endl;}
    catch (...) { std::cerr << "SetOffset Unknown Error" << std::endl;}
}

} // extern "C"