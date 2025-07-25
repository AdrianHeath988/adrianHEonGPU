#ifndef HEONGPU_OPERATOR_C_API_H
#define HEONGPU_OPERATOR_C_API_H

#include "context_c_api.h"
#include "plaintext_c_api.h"
#include "ciphertext_c_api.h"
#include "evaluationkey_c_api.h"
#include "encoder_c_api.h" // HEOperator constructor needs HEEncoder
#include "encryptor_c_api.h"
#include "keygenerator_c_api.h"


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

int HEonGPU_CKKS_ArithmeticOperator_GenerateBootstrappingParams(HE_CKKS_ArithmeticOperator* op,
                                                                double scale,
                                                                const C_BootstrappingConfig* config);

int HEonGPU_CKKS_ArithmeticOperator_GetBootstrappingKeyIndices(HE_CKKS_ArithmeticOperator* op,
                                                               int** out_indices,
                                                               size_t* out_count);

HE_CKKS_Ciphertext* HEonGPU_CKKS_ArithmeticOperator_RegularBootstrapping(HE_CKKS_ArithmeticOperator* op,
                                                                         HE_CKKS_Ciphertext* ct_in,
                                                                         HE_CKKS_GaloisKey* galois_key,
                                                                         HE_CKKS_RelinKey* relin_key,
                                                                         const C_ExecutionOptions* options);
#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_OPERATOR_C_API_H