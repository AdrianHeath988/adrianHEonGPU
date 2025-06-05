#ifndef HEONGPU_OPERATOR_C_API_H
#define HEONGPU_OPERATOR_C_API_H

#include "context_c_api.h"
#include "plaintext_c_api.h"
#include "ciphertext_c_api.h"
#include "evaluationkey_c_api.h"
#include "encoder_c_api.h" // HEOperator constructor needs HEEncoder

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer types
typedef struct HE_CKKS_ArithmeticOperator_s HE_CKKS_ArithmeticOperator;
typedef struct HE_CKKS_LogicOperator_s HE_CKKS_LogicOperator;

// --- CKKS HEArithmeticOperator Lifecycle ---
HE_CKKS_ArithmeticOperator* HEonGPU_CKKS_ArithmeticOperator_Create(HE_CKKS_Context* context, HE_CKKS_Encoder* encoder);
void HEonGPU_CKKS_ArithmeticOperator_Delete(HE_CKKS_ArithmeticOperator* op);

// --- CKKS HEArithmeticOperator Operations ---

// Addition
void HEonGPU_CKKS_ArithmeticOperator_Add_Plain_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const HE_CKKS_Plaintext* pt_in, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Add_Plain(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, const HE_CKKS_Plaintext* pt_in, HE_CKKS_Ciphertext* ct3_out, const C_ExecutionOptions* options);
void HEonGPU_CKKS_ArithmeticOperator_Add_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct1_in_out, const HE_CKKS_Ciphertext* ct2_in, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Add(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct1_in, const HE_CKKS_Ciphertext* ct2_in, HE_CKKS_Ciphertext* ct3_out, const C_ExecutionOptions* options);

// Subtraction
void HEonGPU_CKKS_ArithmeticOperator_Sub_Plain_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const HE_CKKS_Plaintext* pt_in, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Sub_Plain(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, const HE_CKKS_Plaintext* pt_in, HE_CKKS_Ciphertext* ct3_out, const C_ExecutionOptions* options);
void HEonGPU_CKKS_ArithmeticOperator_Sub_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct1_in_out, const HE_CKKS_Ciphertext* ct2_in, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Sub(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct1_in, const HE_CKKS_Ciphertext* ct2_in, HE_CKKS_Ciphertext* ct3_out, const C_ExecutionOptions* options);

// Negation
void HEonGPU_CKKS_ArithmeticOperator_Negate_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Negate(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options);

// Multiplication
void HEonGPU_CKKS_ArithmeticOperator_Multiply_Plain_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const HE_CKKS_Plaintext* pt_in, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Multiply_Plain(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, const HE_CKKS_Plaintext* pt_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options);
void HEonGPU_CKKS_ArithmeticOperator_Multiply_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct1_in_out, const HE_CKKS_Ciphertext* ct2_in, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Multiply(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct1_in, const HE_CKKS_Ciphertext* ct2_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options);

// Relinearization
void HEonGPU_CKKS_ArithmeticOperator_Relinearize_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, HE_CKKS_RelinKey* relin_key, const C_ExecutionOptions* options);

// Modulus Drop / Rescale
void HEonGPU_CKKS_ArithmeticOperator_ModDrop_Ciphertext_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_ModDrop_Ciphertext(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, HE_CKKS_Ciphertext* ct_out, const C_ExecutionOptions* options);
void HEonGPU_CKKS_ArithmeticOperator_ModDrop_Plaintext_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Plaintext* pt_in_out, const C_ExecutionOptions* options);

void HEonGPU_CKKS_ArithmeticOperator_Rescale_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, const C_ExecutionOptions* options);

// Rotation / Conjugation
void HEonGPU_CKKS_ArithmeticOperator_Rotate_Inplace(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in_out, int steps, HE_CKKS_GaloisKey* galois_key, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Rotate(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, HE_CKKS_Ciphertext* ct_out, int steps, HE_CKKS_GaloisKey* galois_key, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Conjugate(HE_CKKS_ArithmeticOperator* op, const HE_CKKS_Ciphertext* ct_in, HE_CKKS_Ciphertext* ct_out, HE_CKKS_GaloisKey* galois_key, const C_ExecutionOptions* options);

// Bootstrapping
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Bootstrap(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in, HE_CKKS_RelinKey* relin_key, HE_CKKS_GaloisKey* galois_key_conj, HE_CKKS_GaloisKey* galois_key_rot, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Bootstrap_Slim(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in, HE_CKKS_RelinKey* relin_key, HE_CKKS_GaloisKey* galois_key_conj, HE_CKKS_GaloisKey* galois_key_rot, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Bootstrap_Bit(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in, HE_CKKS_RelinKey* relin_key, HE_CKKS_GaloisKey* galois_key_conj, HE_CKKS_GaloisKey* galois_key_rot, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_Bootstrap_Gate(HE_CKKS_ArithmeticOperator* op, HE_CKKS_Ciphertext* ct_in, HE_CKKS_RelinKey* relin_key, HE_CKKS_GaloisKey* galois_key_conj, HE_CKKS_GaloisKey* galois_key_rot, const C_ExecutionOptions* options);


// --- CKKS HELogicOperator Lifecycle ---
HE_CKKS_LogicOperator* HEonGPU_CKKS_LogicOperator_Create(HE_CKKS_Context* context, HE_CKKS_Encoder* encoder);
void HEonGPU_CKKS_LogicOperator_Delete(HE_CKKS_LogicOperator* op);

// --- CKKS HELogicOperator Operations ---
void HEonGPU_CKKS_LogicOperator_NOT_Approximation_Inplace(HE_CKKS_LogicOperator* op, HE_CKKS_Ciphertext* ct_in_out, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_LogicOperator_NOT_Approximation(HE_CKKS_LogicOperator* op, HE_CKKS_Ciphertext* ct_in, const C_ExecutionOptions* options);

void HEonGPU_CKKS_LogicOperator_XOR_Approximation_Inplace(HE_CKKS_LogicOperator* op, HE_CKKS_Ciphertext* ct1_in_out, HE_CKKS_Ciphertext* ct2_in, HE_CKKS_GaloisKey* galois_key, HE_CKKS_RelinKey* relin_key, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_LogicOperator_XOR_Approximation(HE_CKKS_LogicOperator* op, HE_CKKS_Ciphertext* ct1_in, HE_CKKS_Ciphertext* ct2_in, HE_CKKS_GaloisKey* galois_key, HE_CKKS_RelinKey* relin_key, const C_ExecutionOptions* options);

void HEonGPU_CKKS_LogicOperator_XNOR_Approximation_Inplace(HE_CKKS_LogicOperator* op, HE_CKKS_Ciphertext* ct1_in_out, HE_CKKS_Ciphertext* ct2_in, HE_CKKS_GaloisKey* galois_key, HE_CKKS_RelinKey* relin_key, const C_ExecutionOptions* options);
HE_CKKS_Ciphertext* HEonGPU_CKKS_LogicOperator_XNOR_Approximation(HE_CKKS_LogicOperator* op, HE_CKKS_Ciphertext* ct1_in, HE_CKKS_Ciphertext* ct2_in, HE_CKKS_GaloisKey* galois_key, HE_CKKS_RelinKey* relin_key, const C_ExecutionOptions* options);


#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_OPERATOR_C_API_H