#ifndef HEONGPU_PLAINTEXT_C_API_H
#define HEONGPU_PLAINTEXT_C_API_H

#include "context_c_api.h" // For HE_CKKS_Context, C_cudaStream_t, C_storage_type, C_ExecutionOptions etc.

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct HE_CKKS_Plaintext_s HE_CKKS_Plaintext;

// --- Lifecycle, Copy, Serialization ---
HE_CKKS_Plaintext* HEonGPU_CKKS_Plaintext_Create(HE_CKKS_Context* context,
                                                 const C_ExecutionOptions* options);
void HEonGPU_CKKS_Plaintext_Delete(HE_CKKS_Plaintext* plaintext);
HE_CKKS_Plaintext* HEonGPU_CKKS_Plaintext_Clone(const HE_CKKS_Plaintext* other_plaintext);
int HEonGPU_CKKS_Plaintext_Assign_Copy(HE_CKKS_Plaintext* dest_plaintext,
                                       const HE_CKKS_Plaintext* src_plaintext);
int HEonGPU_CKKS_Plaintext_Save(HE_CKKS_Plaintext* plaintext,
                                unsigned char** out_bytes,
                                size_t* out_len);
HE_CKKS_Plaintext* HEonGPU_CKKS_Plaintext_Load(HE_CKKS_Context* context,
                                               const unsigned char* bytes,
                                               size_t len,
                                               const C_ExecutionOptions* options);

// --- Getters ---
int HEonGPU_CKKS_Plaintext_GetPlainSize(HE_CKKS_Plaintext* plaintext);
int HEonGPU_CKKS_Plaintext_GetDepth(HE_CKKS_Plaintext* plaintext);
double HEonGPU_CKKS_Plaintext_GetScale(HE_CKKS_Plaintext* plaintext);
bool HEonGPU_CKKS_Plaintext_IsInNttDomain(HE_CKKS_Plaintext* plaintext);
bool HEonGPU_CKKS_Plaintext_IsOnDevice(HE_CKKS_Plaintext* plaintext);
uint64_t* HEonGPU_CKKS_Plaintext_GetData(HE_CKKS_Plaintext* plaintext);


#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_PLAINTEXT_C_API_H