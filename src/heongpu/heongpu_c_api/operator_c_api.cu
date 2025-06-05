#include "operator_c_api.h"
#include "heongpu_c_api_internal.h"
#include "heongpu.cuh"

#include "ckks/context.cuh"
#include "ckks/encoder.cuh"
#include "ckks/plaintext.cuh"
#include "ckks/ciphertext.cuh"
#include "ckks/evaluationkey.cuh"
#include "ckks/operator.cuh" // The C++ classes we are wrapping

#include "storagemanager.cuh" // For heongpu::ExecutionOptions

#include <vector>
#include <iostream> // For error logging
#include <new>      // For std::nothrow


// Define opaque structs
typedef struct HE_CKKS_ArithmeticOperator_s HE_CKKS_ArithmeticOperator;
typedef struct HE_CKKS_LogicOperator_s HE_CKKS_LogicOperator;
// Helper to safely access underlying C++ pointers from opaque C pointers
static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context(HE_CKKS_Context* context) {
    if (!context || !context->cpp_context) return nullptr;
    return context->cpp_context;
}
static heongpu::HEEncoder<heongpu::Scheme::CKKS>* get_cpp_encoder(HE_CKKS_Encoder* encoder) {
    if (!encoder || !encoder->cpp_encoder) return nullptr;
    return encoder->cpp_encoder;
}
static heongpu::Plaintext<heongpu::Scheme::CKKS>* get_cpp_plaintext(HE_CKKS_Plaintext* pt) {
    if (!pt || !pt->cpp_plaintext) return nullptr;
    return pt->cpp_plaintext;
}
static const heongpu::Plaintext<heongpu::Scheme::CKKS>* get_const_cpp_plaintext(const HE_CKKS_Plaintext* pt) {
    if (!pt || !pt->cpp_plaintext) return nullptr;
    return pt->cpp_plaintext;
}
static heongpu::Ciphertext<heongpu::Scheme::CKKS>* get_cpp_ciphertext(HE_CKKS_Ciphertext* ct) {
    if (!ct || !ct->cpp_ciphertext) return nullptr;
    return ct->cpp_ciphertext;
}
static const heongpu::Ciphertext<heongpu::Scheme::CKKS>* get_const_cpp_ciphertext(const HE_CKKS_Ciphertext* ct) {
    if (!ct || !ct->cpp_ciphertext) return nullptr;
    return ct->cpp_ciphertext;
}
static heongpu::Relinkey<heongpu::Scheme::CKKS>* get_cpp_relinkey(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) return nullptr;
    return rk->cpp_relinkey;
}
static heongpu::Galoiskey<heongpu::Scheme::CKKS>* get_cpp_galoiskey(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return nullptr;
    return gk->cpp_galoiskey;
}


// Helper to map C types to C++ ExecutionOptions
static heongpu::ExecutionOptions map_c_to_cpp_execution_options_op(const C_ExecutionOptions* c_options) {
    heongpu::ExecutionOptions cpp_options; // Defaults from C++ struct definition
    if (c_options) {
        cpp_options.stream_ = static_cast<cudaStream_t>(c_options->stream);
        if (c_options->storage == C_STORAGE_TYPE_HOST) {
            cpp_options.storage_ = heongpu::storage_type::HOST;
        } else if (c_options->storage == C_STORAGE_TYPE_DEVICE) {
            cpp_options.storage_ = heongpu::storage_type::DEVICE;
        }
        // If C_STORAGE_TYPE_INVALID or other, it uses default from cpp_options.
        cpp_options.keep_initial_condition_ = c_options->keep_initial_condition;
    }
    return cpp_options;
}


extern "C" {

// --- CKKS HEArithmeticOperator Lifecycle ---
HE_CKKS_ArithmeticOperator* HEonGPU_CKKS_ArithmeticOperator_Create(HE_CKKS_Context* context, HE_CKKS_Encoder* encoder) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    heongpu::HEEncoder<heongpu::Scheme::CKKS>* cpp_h_encoder = get_cpp_encoder(encoder);
    if (!cpp_h_context || !cpp_h_encoder) {
        std::cerr << "ArithmeticOperator_Create: Invalid context or encoder." << std::endl;
        return nullptr;
    }
    try {
        auto cpp_obj = new (std::nothrow) heongpu::HEArithmeticOperator<heongpu::Scheme::CKKS>(*cpp_h_context, *cpp_h_encoder);
        if (!cpp_obj) return nullptr;
        auto c_api_obj = new (std::nothrow) HE_CKKS_ArithmeticOperator_s;
        if (!c_api_obj) { delete cpp_obj; return nullptr; }
        c_api_obj->cpp_arith_op = cpp_obj;
        return c_api_obj;
    } catch (const std::exception& e) { std::cerr << "ArithmeticOperator_Create Error: " << e.what() << std::endl; return nullptr;} 
      catch (...) { std::cerr << "ArithmeticOperator_Create Unknown Error" << std::endl; return nullptr;}
}

void HEonGPU_CKKS_ArithmeticOperator_Delete(HE_CKKS_ArithmeticOperator* op) {
    if (op) { delete op->cpp_arith_op; delete op; }
}

// --- CKKS HEArithmeticOperator Operations ---

// Addition Example (In-place)
void HEonGPU_CKKS_ArithmeticOperator_Add_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct1_in_out, const HE_CKKS_Ciphertext* ct2_in, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct1_in_out || !ct1_in_out->cpp_ciphertext || !ct2_in || !ct2_in->cpp_ciphertext) {
        std::cerr << "Add_Inplace: Invalid argument(s).\n"; return;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->add_inplace(*(ct1_in_out->cpp_ciphertext), *(ct2_in->cpp_ciphertext), cpp_options);
    } catch (const std::exception& e) { std::cerr << "Add_Inplace Error: " << e.what() << std::endl; }
      catch (...) { std::cerr << "Add_Inplace Unknown Error" << std::endl;}
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Add(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct1_in, const HE_CKKS_Ciphertext* ct2_in, HE_CKKS_Ciphertext* ct3_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct1_in || !ct1_in->cpp_ciphertext || !ct2_in || !ct2_in->cpp_ciphertext) {
        std::cerr << "Add: Invalid argument(s).\n"; return nullptr;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->add(*(ct1_in->cpp_ciphertext), *(ct2_in->cpp_ciphertext), *(ct3_out->cpp_ciphertext), cpp_options);
        return ct3_out;
    } catch (const std::exception& e) { std::cerr << "Add Error: " << e.what() << std::endl; return nullptr; }
      catch (...) { std::cerr << "Add Unknown Error" << std::endl; return nullptr; }
}

// Add_Plain_Inplace
void HEonGPU_CKKS_ArithmeticOperator_Add_Plain_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const HE_CKKS_Plaintext* pt_in, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext || !pt_in || !pt_in->cpp_plaintext) {
        std::cerr << "Add_Plain_Inplace: Invalid argument(s).\n"; return;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->add_plain_inplace(*(ct_in_out->cpp_ciphertext), *(pt_in->cpp_plaintext), cpp_options);
    } catch (const std::exception& e) { std::cerr << "Add_Plain_Inplace Error: " << e.what() << std::endl; }
      catch (...) { std::cerr << "Add_Plain_Inplace Unknown Error" << std::endl;}
}

// Add_Plain (returns new Ciphertext)
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Add_Plain(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, const HE_CKKS_Plaintext* pt_in, HE_CKKS_Ciphertext* ct3_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in || !ct_in->cpp_ciphertext || !pt_in || !pt_in->cpp_plaintext) {
        std::cerr << "Add_Plain: Invalid argument(s).\n"; return nullptr;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        
        op->cpp_arith_op->add_plain(*(ct_in->cpp_ciphertext), *(pt_in->cpp_plaintext), *(ct3_out->cpp_ciphertext), cpp_options);
        return ct3_out;
    } catch (const std::exception& e) { std::cerr << "Add_Plain Error: " << e.what() << std::endl; return nullptr;}
      catch (...) { std::cerr << "Add_Plain Unknown Error" << std::endl; return nullptr;}
}


// --- Implementations for Subtraction (similar to Addition) ---
void HEonGPU_CKKS_ArithmeticOperator_Sub_Plain_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const HE_CKKS_Plaintext* pt_in, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext || !pt_in || !pt_in->cpp_plaintext) return;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->sub_plain_inplace(*(ct_in_out->cpp_ciphertext), *(pt_in->cpp_plaintext), cpp_options);
    } catch (...) { /* error handling */ }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Sub_Plain(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, const HE_CKKS_Plaintext* pt_in, HE_CKKS_Ciphertext* ct3_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in || !ct_in->cpp_ciphertext || !pt_in || !pt_in->cpp_plaintext) return nullptr;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->sub_plain(*(ct_in->cpp_ciphertext), *(pt_in->cpp_plaintext), *(ct3_out->cpp_ciphertext), cpp_options);
        
        return ct3_out;
    } catch (...) { return nullptr; }
}

void HEonGPU_CKKS_ArithmeticOperator_Sub_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct1_in_out, const HE_CKKS_Ciphertext* ct2_in, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct1_in_out || !ct1_in_out->cpp_ciphertext || !ct2_in || !ct2_in->cpp_ciphertext) return;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->sub_inplace(*(ct1_in_out->cpp_ciphertext), *(ct2_in->cpp_ciphertext), cpp_options);
    } catch (...) { /* error handling */ }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Sub(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct1_in, const HE_CKKS_Ciphertext* ct2_in, HE_CKKS_Ciphertext* ct3_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct1_in || !ct1_in->cpp_ciphertext || !ct2_in || !ct2_in->cpp_ciphertext) return nullptr;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->sub(*(ct1_in->cpp_ciphertext), *(ct2_in->cpp_ciphertext), *(ct3_out->cpp_ciphertext), cpp_options);
        
        return ct3_out;
    } catch (...) { return nullptr; }
}

// --- Negation ---
void HEonGPU_CKKS_ArithmeticOperator_Negate_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext) return;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->negate_inplace(*(ct_in_out->cpp_ciphertext), cpp_options);
    } catch (...) { /* error handling */ }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Negate(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in || !ct_in->cpp_ciphertext) return nullptr;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->negate(*(ct_in->cpp_ciphertext), *(ct_out->cpp_ciphertext), cpp_options);
        return ct_out;
    } catch (...) { return nullptr; }
}

// --- Implementations for Multiplication (Pattern: check args, map options, call C++ method, wrap result if new object) ---
void HEonGPU_CKKS_ArithmeticOperator_Multiply_Plain_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const HE_CKKS_Plaintext* pt_in, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext || !pt_in || !pt_in->cpp_plaintext) return;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->multiply_plain_inplace(*(ct_in_out->cpp_ciphertext), *(pt_in->cpp_plaintext), cpp_options);
    } catch (...) { /* error handling */ }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Multiply_Plain(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, const HE_CKKS_Plaintext* pt_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in || !ct_in->cpp_ciphertext || !pt_in || !pt_in->cpp_plaintext) return nullptr;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->multiply_plain(*(ct_in->cpp_ciphertext), *(pt_in->cpp_plaintext), *(ct_out->cpp_ciphertext), cpp_options);
        
        return ct_out;
    } catch (...) { return nullptr; }
}

void HEonGPU_CKKS_ArithmeticOperator_Multiply_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct1_in_out, const HE_CKKS_Ciphertext* ct2_in, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct1_in_out || !ct1_in_out->cpp_ciphertext || !ct2_in || !ct2_in->cpp_ciphertext) return;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->multiply_inplace(*(ct1_in_out->cpp_ciphertext), *(ct2_in->cpp_ciphertext), cpp_options);
    } catch (...) { /* error handling */ }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Multiply(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct1_in, const HE_CKKS_Ciphertext* ct2_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct1_in || !ct1_in->cpp_ciphertext || !ct2_in || !ct2_in->cpp_ciphertext || !ct_out || !ct_out->cpp_ciphertext) return nullptr;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->multiply(*(ct1_in->cpp_ciphertext), *(ct2_in->cpp_ciphertext), *(ct_out->cpp_ciphertext), cpp_options);
        return ct_out;
    } catch (...) { return nullptr; }
}



// --- Relinearize ---
void HEonGPU_CKKS_ArithmeticOperator_Relinearize_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, HE_CKKS_RelinKey* relin_key_c, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext || !relin_key_c || !relin_key_c->cpp_relinkey) return;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->relinearize_inplace(*(ct_in_out->cpp_ciphertext), *(relin_key_c->cpp_relinkey), cpp_options);
    } catch (...) { /* error handling */ }
}

// --- ModDrop / Rescale ---
void HEonGPU_CKKS_ArithmeticOperator_ModDrop_Ciphertext_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext) return;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->mod_drop_inplace(*(ct_in_out->cpp_ciphertext), cpp_options);
    } catch (...) { /* error handling */ }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_ModDrop_Ciphertext(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in || !ct_in->cpp_ciphertext) return nullptr;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->mod_drop(*(ct_in->cpp_ciphertext), *(ct_out->cpp_ciphertext), cpp_options);
        
        return ct_out;
    } catch (...) { return nullptr; }
}

void HEonGPU_CKKS_ArithmeticOperator_ModDrop_Plaintext_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Plaintext* pt_in_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !pt_in_out || !pt_in_out->cpp_plaintext) return;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->mod_drop_inplace(*(pt_in_out->cpp_plaintext), cpp_options);
    } catch (...) { /* error handling */ }
}


void HEonGPU_CKKS_ArithmeticOperator_Rescale_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext) return;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->rescale_inplace(*(ct_in_out->cpp_ciphertext), cpp_options);
    } catch (...) { /* error handling */ }
}



// --- Rotation / Conjugation ---
void HEonGPU_CKKS_ArithmeticOperator_Rotate_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, int steps, HE_CKKS_GaloisKey* galois_key_c, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext || !galois_key_c || !galois_key_c->cpp_galoiskey) return;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->rotate_rows_inplace(*(ct_in_out->cpp_ciphertext), *(galois_key_c->cpp_galoiskey), steps, cpp_options);
    } catch (...) { /* error handling */ }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Rotate(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, HE_CKKS_Ciphertext* ct_out, int steps, HE_CKKS_GaloisKey* galois_key_c, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in || !ct_in->cpp_ciphertext || !galois_key_c || !galois_key_c->cpp_galoiskey) return nullptr;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->rotate_rows(*(ct_in->cpp_ciphertext), *(ct_out->cpp_ciphertext), *(galois_key_c->cpp_galoiskey),steps, cpp_options);
        
        return ct_out;
    } catch (...) { return nullptr; }
}


HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Conjugate(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, HE_CKKS_Ciphertext* ct_out, HE_CKKS_GaloisKey* galois_key_c, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in || !ct_in->cpp_ciphertext || !galois_key_c || !galois_key_c->cpp_galoiskey) return nullptr;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->conjugate(*(ct_in->cpp_ciphertext),*(ct_out->cpp_ciphertext), *(galois_key_c->cpp_galoiskey), cpp_options);
        
        return ct_out;
    } catch (...) { return nullptr; }
}


// --- Bootstrapping ---
// Note: C++ bootstrap methods return new Ciphertext objects.

// Bootstrapping will be wrapped after non-bootstrapping works.

// #define WRAP_BOOTSTRAP_FUNC(FuncName, CppFuncName) \
// HE_CKKS_Ciphertext* FuncName(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_c, HE_CKKS_RelinKey* relin_key_c, HE_CKKS_GaloisKey* galois_key_conj_c, HE_CKKS_GaloisKey* galois_key_rot_c, const C_ExecutionOptions* options_c) { \
//     if (!op || !op->cpp_arith_op || !ct_in_c || !ct_in_c->cpp_ciphertext || \
//         !relin_key_c || !relin_key_c->cpp_relinkey || \
//         !galois_key_conj_c || !galois_key_conj_c->cpp_galoiskey || \
//         !galois_key_rot_c || !galois_key_rot_c->cpp_galoiskey) { \
//         std::cerr << #FuncName " Error: Invalid argument(s).\n"; return nullptr; \
//     } \
//     try { \
//         heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c); \
//         auto cpp_result = op->cpp_arith_op->CppFuncName(*(ct_in_c->cpp_ciphertext), *(relin_key_c->cpp_relinkey), *(galois_key_conj_c->cpp_galoiskey), *(galois_key_rot_c->cpp_galoiskey), cpp_options); \
//         auto cpp_heap_result = new (std::nothrow) heongpu::Ciphertext<heongpu::Scheme::CKKS>(std::move(cpp_result)); \
//         if (!cpp_heap_result) return nullptr; \
//         auto c_api_result = new (std::nothrow) HE_CKKS_Ciphertext_s; \
//         if (!c_api_result) { delete cpp_heap_result; return nullptr; } \
//         c_api_result->cpp_ciphertext = cpp_heap_result; \
//         return c_api_result; \
//     } catch (const std::exception& e) { std::cerr << #FuncName " Error: " << e.what() << std::endl; return nullptr; } \
//       catch (...) { std::cerr << #FuncName " Unknown Error" << std::endl; return nullptr; } \
// }

// WRAP_BOOTSTRAP_FUNC(HEonGPU_CKKS_ArithmeticOperator_Bootstrap, bootstrap)
// WRAP_BOOTSTRAP_FUNC(HEonGPU_CKKS_ArithmeticOperator_Bootstrap_Slim, bootstrap_slim)
// WRAP_BOOTSTRAP_FUNC(HEonGPU_CKKS_ArithmeticOperator_Bootstrap_Bit, bootstrap_bit)
// WRAP_BOOTSTRAP_FUNC(HEonGPU_CKKS_ArithmeticOperator_Bootstrap_Gate, bootstrap_gate)


// --- CKKS HELogicOperator Lifecycle ---
// I believe this to be unnecassary for Orion operations.

// HE_CKKS_LogicOperator* HEonGPU_CKKS_LogicOperator_Create(HE_CKKS_Context* context, HE_CKKS_Encoder* encoder) {
//     heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
//     heongpu::HEEncoder<heongpu::Scheme::CKKS>* cpp_h_encoder = get_cpp_encoder(encoder);
//      if (!cpp_h_context || !cpp_h_encoder) {
//         std::cerr << "LogicOperator_Create: Invalid context or encoder." << std::endl;
//         return nullptr;
//     }
//     try {
//         auto cpp_obj = new (std::nothrow) heongpu::HELogicOperator<heongpu::Scheme::CKKS>(*cpp_h_context, *cpp_h_encoder);
//         if (!cpp_obj) return nullptr;
//         auto c_api_obj = new (std::nothrow) HE_CKKS_LogicOperator_s;
//         if (!c_api_obj) { delete cpp_obj; return nullptr; }
//         c_api_obj->cpp_logic_op = cpp_obj;
//         return c_api_obj;
//     } catch (const std::exception& e) { std::cerr << "LogicOperator_Create Error: " << e.what() << std::endl; return nullptr;}
//       catch (...) { std::cerr << "LogicOperator_Create Unknown Error" << std::endl; return nullptr;}
// }

// void HEonGPU_CKKS_LogicOperator_Delete(HE_CKKS_LogicOperator* op) {
//     if (op) { delete op->cpp_logic_op; delete op; }
// }

// // --- CKKS HELogicOperator Operations ---
// void HEonGPU_CKKS_LogicOperator_NOT_Approximation_Inplace(HE_CKKS_LogicOperator* op, HE_CKKS_Ciphertext* ct_in_out, const C_ExecutionOptions* options_c) {
//     if (!op || !op->cpp_logic_op || !ct_in_out || !ct_in_out->cpp_ciphertext) return;
//     try {
//         heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
//         op->cpp_logic_op->NOT_approximation_inplace(*(ct_in_out->cpp_ciphertext), cpp_options);
//     } catch (...) { /* error handling */ }
// }

// HE_CKKS_Ciphertext* HEonGPU_CKKS_LogicOperator_NOT_Approximation(HE_CKKS_LogicOperator* op, HE_CKKS_Ciphertext* ct_in_c, const C_ExecutionOptions* options_c) {
//     if (!op || !op->cpp_logic_op || !ct_in_c || !ct_in_c->cpp_ciphertext) return nullptr;
//     try {
//         heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
//         auto cpp_result = op->cpp_logic_op->NOT_approximation(*(ct_in_c->cpp_ciphertext), cpp_options);
//         auto cpp_heap_result = new (std::nothrow) heongpu::Ciphertext<heongpu::Scheme::CKKS>(std::move(cpp_result));
//         if (!cpp_heap_result) return nullptr;
//         auto c_api_result = new (std::nothrow) HE_CKKS_Ciphertext_s;
//         if (!c_api_result) { delete cpp_heap_result; return nullptr; }
//         c_api_result->cpp_ciphertext = cpp_heap_result;
//         return c_api_result;
//     } catch (...) { return nullptr; }
// }

// // (XOR and XNOR functions follow a similar pattern, taking GaloisKey and RelinKey)
// #define WRAP_LOGIC_BINARY_OP_INPLACE(FuncName, CppFuncName) \
// void FuncName(HE_CKKS_LogicOperator* op, HE_CKKS_Ciphertext* ct1_in_out_c, HE_CKKS_Ciphertext* ct2_in_c, HE_CKKS_GaloisKey* galois_key_c, HE_CKKS_RelinKey* relin_key_c, const C_ExecutionOptions* options_c) { \
//     if (!op || !op->cpp_logic_op || !ct1_in_out_c || !ct1_in_out_c->cpp_ciphertext || \
//         !ct2_in_c || !ct2_in_c->cpp_ciphertext || \
//         !galois_key_c || !galois_key_c->cpp_galoiskey || \
//         !relin_key_c || !relin_key_c->cpp_relinkey) { \
//         std::cerr << #FuncName " Error: Invalid argument(s).\n"; return; \
//     } \
//     try { \
//         heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c); \
//         op->cpp_logic_op->CppFuncName(*(ct1_in_out_c->cpp_ciphertext), *(ct2_in_c->cpp_ciphertext), *(galois_key_c->cpp_galoiskey), *(relin_key_c->cpp_relinkey), cpp_options); \
//     } catch (const std::exception& e) { std::cerr << #FuncName " Error: " << e.what() << std::endl; } \
//       catch (...) { std::cerr << #FuncName " Unknown Error" << std::endl; } \
// }

// #define WRAP_LOGIC_BINARY_OP_NEW(FuncName, CppFuncName) \
// HE_CKKS_Ciphertext* FuncName(HE_CKKS_LogicOperator* op, HE_CKKS_Ciphertext* ct1_in_c, HE_CKKS_Ciphertext* ct2_in_c, HE_CKKS_GaloisKey* galois_key_c, HE_CKKS_RelinKey* relin_key_c, const C_ExecutionOptions* options_c) { \
//     if (!op || !op->cpp_logic_op || !ct1_in_c || !ct1_in_c->cpp_ciphertext || \
//         !ct2_in_c || !ct2_in_c->cpp_ciphertext || \
//         !galois_key_c || !galois_key_c->cpp_galoiskey || \
//         !relin_key_c || !relin_key_c->cpp_relinkey) { \
//         std::cerr << #FuncName " Error: Invalid argument(s).\n"; return nullptr; \
//     } \
//     try { \
//         heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c); \
//         auto cpp_result = op->cpp_logic_op->CppFuncName(*(ct1_in_c->cpp_ciphertext), *(ct2_in_c->cpp_ciphertext), *(galois_key_c->cpp_galoiskey), *(relin_key_c->cpp_relinkey), cpp_options); \
//         auto cpp_heap_result = new (std::nothrow) heongpu::Ciphertext<heongpu::Scheme::CKKS>(std::move(cpp_result)); \
//         if (!cpp_heap_result) return nullptr; \
//         auto c_api_result = new (std::nothrow) HE_CKKS_Ciphertext_s; \
//         if (!c_api_result) { delete cpp_heap_result; return nullptr; } \
//         c_api_result->cpp_ciphertext = cpp_heap_result; \
//         return c_api_result; \
//     } catch (const std::exception& e) { std::cerr << #FuncName " Error: " << e.what() << std::endl; return nullptr; } \
//       catch (...) { std::cerr << #FuncName " Unknown Error" << std::endl; return nullptr; } \
// }

// WRAP_LOGIC_BINARY_OP_INPLACE(HEonGPU_CKKS_LogicOperator_XOR_Approximation_Inplace, XOR_approximation_inplace)
// WRAP_LOGIC_BINARY_OP_NEW(HEonGPU_CKKS_LogicOperator_XOR_Approximation, XOR_approximation)
// WRAP_LOGIC_BINARY_OP_INPLACE(HEonGPU_CKKS_LogicOperator_XNOR_Approximation_Inplace, XNOR_approximation_inplace)
// WRAP_LOGIC_BINARY_OP_NEW(HEonGPU_CKKS_LogicOperator_XNOR_Approximation, XNOR_approximation)


} // extern "C"