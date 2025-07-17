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
static heongpu::HEArithmeticOperator<heongpu::Scheme::CKKS>* get_cpp_arith_op(HE_CKKS_ArithmeticOperator* op) {
    if (!op || !op->cpp_arith_op) return nullptr;
    return op->cpp_arith_op;
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
static heongpu::ExecutionOptions map_c_to_cpp_execution_options(const C_ExecutionOptions* c_options) {
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
    } catch (const std::exception& e) { 
        std::cerr << "Add_Plain_Inplace Error: " << e.what() << std::endl; 
        if (ct_in_out && ct_in_out->cpp_ciphertext) {
            std::cerr << "    Offending Ciphertext Depth: " << ct_in_out->cpp_ciphertext->depth() << std::endl;
        }
        if (pt_in && pt_in->cpp_plaintext) {
            std::cerr << "    Offending Plaintext Depth: " << pt_in->cpp_plaintext->depth() << std::endl;
        }
    }
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
    std::cout << "[C++ DEBUG] Entered HEonGPU_CKKS_ArithmeticOperator_Multiply_Plain_Inplace." << std::endl;

    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext || !pt_in || !pt_in->cpp_plaintext) {
        // Added a more descriptive error message here
        std::cerr << "Multiply_Plain_Inplace Error: Received a null pointer for one of the arguments." << std::endl;
        return;
    }

    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->multiply_plain_inplace(*(ct_in_out->cpp_ciphertext), *(pt_in->cpp_plaintext), cpp_options);
    
    // --- Modified error handling to print exceptions ---
    } catch (const std::exception& e) {
        // This will catch standard C++ exceptions (like std::invalid_argument) and print their messages.
        std::cerr << "Multiply_Plain_Inplace caught a standard exception: " << e.what() << std::endl;
        if (ct_in_out && ct_in_out->cpp_ciphertext) {
            std::cerr << "    Offending Ciphertext Depth: " << ct_in_out->cpp_ciphertext->depth() << std::endl;
        }
        if (pt_in && pt_in->cpp_plaintext) {
            std::cerr << "    Offending Plaintext Depth: " << pt_in->cpp_plaintext->depth() << std::endl;
        }
    } catch (...) {
        // This is a catch-all for any other non-standard exceptions.
        std::cerr << "Multiply_Plain_Inplace caught an unknown exception." << std::endl;
    }
}


HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Multiply_Plain(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, const HE_CKKS_Plaintext* pt_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in || !ct_in->cpp_ciphertext || !pt_in || !pt_in->cpp_plaintext) {
        std::cerr << "Multiply_Plain Error: Received a null pointer for one of the arguments." << std::endl;
        return nullptr;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->multiply_plain(*(ct_in->cpp_ciphertext), *(pt_in->cpp_plaintext), *(ct_out->cpp_ciphertext), cpp_options);
        
        return ct_out;
    } catch (const std::exception& e) {
        // This will catch standard C++ exceptions and print their messages.
        std::cerr << "Multiply_Plain caught a standard exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        // This is a catch-all for any other non-standard exceptions.
        std::cerr << "Multiply_Plain caught an unknown exception." << std::endl;
        return nullptr;
    }
}


void HEonGPU_CKKS_ArithmeticOperator_Multiply_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct1_in_out, const HE_CKKS_Ciphertext* ct2_in, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct1_in_out || !ct1_in_out->cpp_ciphertext || !ct2_in || !ct2_in->cpp_ciphertext) {
        std::cerr << "Multiply_Inplace Error: Received a null pointer for one of the arguments." << std::endl;
        return;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->multiply_inplace(*(ct1_in_out->cpp_ciphertext), *(ct2_in->cpp_ciphertext), cpp_options);
    } catch (const std::exception& e) {
        std::cerr << "Multiply_Inplace caught a standard exception: " << e.what() << std::endl;
    } catch (...) {
        std::cerr << "Multiply_Inplace caught an unknown exception." << std::endl;
    }
}


HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Multiply(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct1_in, const HE_CKKS_Ciphertext* ct2_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct1_in || !ct1_in->cpp_ciphertext || !ct2_in || !ct2_in->cpp_ciphertext || !ct_out || !ct_out->cpp_ciphertext) {
        std::cerr << "Multiply Error: Received a null pointer for one of the arguments." << std::endl;
        return nullptr;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->multiply(*(ct1_in->cpp_ciphertext), *(ct2_in->cpp_ciphertext), *(ct_out->cpp_ciphertext), cpp_options);
        return ct_out;
    } catch (const std::exception& e) {
        std::cerr << "Multiply caught a standard exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "Multiply caught an unknown exception." << std::endl;
        return nullptr;
    }
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
    // Initial null pointer check remains the same
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext) {
        std::cerr << "ModDrop_Inplace Error: Invalid operator or ciphertext pointer." << std::endl;
        return;
    }

    // --- Add this try...catch block for detailed error reporting ---
    try {
        std::cout << "    in HEonGPU_CKKS_ArithmeticOperator_ModDrop_Ciphertext_Inplace: " << std::endl;
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->mod_drop_inplace(*(ct_in_out->cpp_ciphertext), cpp_options);
        std::cout << "    rescale_required: "
                  << ct_in_out->cpp_ciphertext->rescale_required() << std::endl;
        std::cout << "    relinearization_required: "
                  << ct_in_out->cpp_ciphertext->relinearization_required() << std::endl;
    } catch (const std::exception& e) {
        // This will print the specific C++ exception message to your console.
        std::cerr << "[C++ EXCEPTION] A standard exception was caught in ModDrop_Inplace: "
                  << e.what() << std::endl;
    } catch (...) {
        // This is a fallback for non-standard exceptions.
        std::cerr << "[C++ EXCEPTION] An unknown exception was caught in ModDrop_Inplace." << std::endl;
    }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_ModDrop_Ciphertext(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !ct_in || !ct_in->cpp_ciphertext) {
        std::cerr << "ModDrop_Ciphertext Error: Received a null pointer for one of the arguments." << std::endl;
        return nullptr;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->mod_drop(*(ct_in->cpp_ciphertext), *(ct_out->cpp_ciphertext), cpp_options);
        
        return ct_out;
    } catch (const std::exception& e) {
        // This will catch standard C++ exceptions and print their messages.
        std::cerr << "ModDrop_Ciphertext caught a standard exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        // This is a catch-all for any other non-standard exceptions.
        std::cerr << "ModDrop_Ciphertext caught an unknown exception." << std::endl;
        return nullptr;
    }
}


void HEonGPU_CKKS_ArithmeticOperator_ModDrop_Plaintext_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Plaintext* pt_in_out, const C_ExecutionOptions* options_c) {
    if (!op || !op->cpp_arith_op || !pt_in_out || !pt_in_out->cpp_plaintext) {
        std::cerr << "ModDrop_Plaintext_Inplace Error: Received a null pointer for one of the arguments." << std::endl;
        return;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->mod_drop_inplace(*(pt_in_out->cpp_plaintext), cpp_options);
    } catch (const std::exception& e) {
        std::cerr << "ModDrop_Plaintext_Inplace caught a standard exception: " << e.what() << std::endl;
    } catch (...) {
        std::cerr << "ModDrop_Plaintext_Inplace caught an unknown exception." << std::endl;
    }
}


void HEonGPU_CKKS_ArithmeticOperator_Rescale_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const C_ExecutionOptions* options_c) {
    // Initial null pointer check remains the same
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext) {
        std::cerr << "Rescale_Inplace Error: Invalid operator or ciphertext pointer." << std::endl;
        return;
    }


    try {
        
        std::cout << "    in HEonGPU_CKKS_ArithmeticOperator_Rescale_Inplace: " << std::endl;
        std::cout << "  ct_in pointer: " << ct_in_out << std::endl;
        if (ct_in_out) std::cout << "  ct_in->cpp_ciphertext: " << ct_in_out->cpp_ciphertext << std::endl;
        std::cout << "    rescale_required: "
                  << ct_in_out->cpp_ciphertext->rescale_required() << std::endl;
        std::cout << "    relinearization_required: "
                  << ct_in_out->cpp_ciphertext->relinearization_required() << std::endl;
        if(!ct_in_out->cpp_ciphertext->rescale_required()){
            return;
        }
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->rescale_inplace(*(ct_in_out->cpp_ciphertext), cpp_options);
    } catch (const std::exception& e) {
        // This will print the specific C++ exception message to your console.
        std::cerr << "[C++ EXCEPTION] A standard exception was caught in Rescale_Inplace: "
                  << e.what() << std::endl;
    } catch (...) {
        // This is a fallback for non-standard exceptions.
        std::cerr << "[C++ EXCEPTION] An unknown exception was caught in Rescale_Inplace." << std::endl;
    }
}




// --- Rotation / Conjugation ---
void HEonGPU_CKKS_ArithmeticOperator_Rotate_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, int steps, HE_CKKS_GaloisKey* galois_key_c, const C_ExecutionOptions* options_c) {
    std::cerr  << "[C++ DEBUG] Rotate Inplace Check:" << std::endl;
    if (!op || !op->cpp_arith_op || !ct_in_out || !ct_in_out->cpp_ciphertext || !galois_key_c || !galois_key_c->cpp_galoiskey) {
        std::cerr << "Rotate_Inplace Error: Received a null pointer for one of the arguments." << std::endl;
        return;
    }
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->rotate_rows_inplace(*(ct_in_out->cpp_ciphertext), *(galois_key_c->cpp_galoiskey), steps, cpp_options);
    
    } catch (const std::exception& e) {
        // This will catch standard C++ exceptions and print their messages.
        std::cerr << "Rotate_Inplace caught a standard exception: " << e.what() << std::endl;
    } catch (...) {
        // This is a catch-all for any other non-standard exceptions.
        std::cerr << "Rotate_Inplace caught an unknown exception." << std::endl;
    }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Rotate(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, HE_CKKS_Ciphertext* ct_out, int steps, HE_CKKS_GaloisKey* galois_key_c, const C_ExecutionOptions* options_c) {
    std::cerr << "[C++ DEBUG] Rotate Check:" << std::endl;
    std::cout << "  op pointer: " << op << std::endl;
    if (op) std::cout << "  op->cpp_arith_op: " << op->cpp_arith_op << std::endl;
    std::cout << "  ct_in pointer: " << ct_in << std::endl;
    if (ct_in) std::cout << "  ct_in->cpp_ciphertext: " << ct_in->cpp_ciphertext << std::endl;
    if (ct_in && ct_in->cpp_ciphertext) {
        std::cout << "  [C++ DEBUG] Flags before Rotate:" << std::endl;
        std::cout << "    rescale_required: "
                  << ct_in->cpp_ciphertext->rescale_required() << std::endl;
        std::cout << "    relinearization_required: "
                  << ct_in->cpp_ciphertext->relinearization_required() << std::endl;
    }


    std::cout << "  galois_key_c pointer: " << galois_key_c << std::endl;
    if (galois_key_c) std::cout << "  galois_key_c->cpp_galoiskey: " << galois_key_c->cpp_galoiskey << std::endl;

    
    if (!op || !op->cpp_arith_op || !ct_in || !ct_in->cpp_ciphertext || !galois_key_c || !galois_key_c->cpp_galoiskey) return nullptr;
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options_op(options_c);
        op->cpp_arith_op->rotate_rows(*(ct_in->cpp_ciphertext), *(ct_out->cpp_ciphertext), *(galois_key_c->cpp_galoiskey), steps, cpp_options);
        return ct_out;
    } catch (const std::exception& e) {
        // This will print the actual C++ error message to your console
        std::cerr << "[C++ EXCEPTION] A standard exception was caught in Rotate: "
                  << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        // This is a fallback for non-standard exceptions
        std::cerr << "[C++ EXCEPTION] An unknown exception was caught in Rotate." << std::endl;
        return nullptr;
    }

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
int HEonGPU_CKKS_ArithmeticOperator_GenerateBootstrappingParams(HE_CKKS_ArithmeticOperator* op,
                                                                double scale,
                                                                const C_BootstrappingConfig* config) {
    heongpu::HEArithmeticOperator<heongpu::Scheme::CKKS>* cpp_op = get_cpp_arith_op(op);
    if (!cpp_op || !config) {
        std::cerr << "GenerateBootstrappingParams Error: Invalid operator or config pointer.\n";
        return -1;
    }
    try {
        heongpu::BootstrappingConfig cpp_config(config->CtoS_piece, config->StoC_piece, config->taylor_number, config->less_key_mode);
        cpp_op->generate_bootstrapping_params(scale, cpp_config);
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GenerateBootstrappingParams failed with exception: " << e.what() << std::endl;
        return -2;
    } catch (...) {
        std::cerr << "GenerateBootstrappingParams failed with unknown exception." << std::endl;
        return -2;
    }
}

int HEonGPU_CKKS_ArithmeticOperator_GetBootstrappingKeyIndices(HE_CKKS_ArithmeticOperator* op,
                                                               int** out_indices,
                                                               size_t* out_count) {
    heongpu::HEArithmeticOperator<heongpu::Scheme::CKKS>* cpp_op = get_cpp_arith_op(op);
    if (!cpp_op || !out_indices || !out_count) {
        if (out_indices) *out_indices = nullptr;
        if (out_count) *out_count = 0;
        return -1;
    }
    *out_indices = nullptr;
    *out_count = 0;
    try {
        std::vector<int> cpp_indices = cpp_op->bootstrapping_key_indexs();
        *out_count = cpp_indices.size();
        if (*out_count > 0) {
            *out_indices = static_cast<int*>(malloc(*out_count * sizeof(int)));
            if (!*out_indices) {
                *out_count = 0;
                std::cerr << "GetBootstrappingKeyIndices: malloc failed.\n";
                return -2;
            }
            std::memcpy(*out_indices, cpp_indices.data(), *out_count * sizeof(int));
        }
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GetBootstrappingKeyIndices failed with exception: " << e.what() << std::endl;
        if (*out_indices) { free(*out_indices); *out_indices = nullptr; }
        *out_count = 0;
        return -3;
    } catch (...) {
        std::cerr << "GetBootstrappingKeyIndices failed with unknown exception." << std::endl;
        if (*out_indices) { free(*out_indices); *out_indices = nullptr; }
        *out_count = 0;
        return -3;
    }
}

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_RegularBootstrapping(HE_CKKS_ArithmeticOperator* op,
                                                                         HE_CKKS_Ciphertext* ct_in_c,
                                                                         HE_CKKS_GaloisKey* galois_key_c,
                                                                         HE_CKKS_RelinKey* relin_key_c,
                                                                         const C_ExecutionOptions* options_c) {
    heongpu::HEArithmeticOperator<heongpu::Scheme::CKKS>* cpp_op = get_cpp_arith_op(op);
    if (!cpp_op || !ct_in_c || !galois_key_c || !relin_key_c) {
        std::cerr << "RegularBootstrapping Error: Invalid argument(s).\n";
        return nullptr;
    }

    heongpu::Ciphertext<heongpu::Scheme::CKKS>* cpp_ct_in = get_cpp_ciphertext(ct_in_c);
    heongpu::Galoiskey<heongpu::Scheme::CKKS>* cpp_gk = get_cpp_galoiskey(galois_key_c);
    heongpu::Relinkey<heongpu::Scheme::CKKS>* cpp_rk = get_cpp_relinkey(relin_key_c);

    if (!cpp_ct_in || !cpp_gk || !cpp_rk) {
        std::cerr << "RegularBootstrapping Error: Failed to unwrap C API handles.\n";
        return nullptr;
    }
    
    try {
        heongpu::ExecutionOptions cpp_options = map_c_to_cpp_execution_options(options_c);
        heongpu::Ciphertext<heongpu::Scheme::CKKS> cpp_result_ct =
            cpp_op->regular_bootstrapping(*cpp_ct_in, *cpp_gk, *cpp_rk, cpp_options);

        // Wrap the returned C++ object in a new C API handle
        auto cpp_heap_result = new (std::nothrow) heongpu::Ciphertext<heongpu::Scheme::CKKS>(std::move(cpp_result_ct));
        if (!cpp_heap_result) return nullptr;

        HE_CKKS_Ciphertext* c_api_result = new (std::nothrow) HE_CKKS_Ciphertext_s;
        if (!c_api_result) { delete cpp_heap_result; return nullptr; }
        
        c_api_result->cpp_ciphertext = cpp_heap_result;
        return c_api_result;

    } catch (const std::exception& e) {
        std::cerr << "RegularBootstrapping failed with exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "RegularBootstrapping failed with unknown exception." << std::endl;
        return nullptr;
    }
}



} // extern "C"