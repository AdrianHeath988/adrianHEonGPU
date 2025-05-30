#ifndef HEONGPU_EVALUATIONKEY_C_API_H
#define HEONGPU_EVALUATIONKEY_C_API_H

#include "context_c_api.h" // For HE_CKKS_Context, C types, free functions etc.

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer types
typedef struct HE_CKKS_RelinKey_s HE_CKKS_RelinKey;
typedef struct HE_CKKS_MultipartyRelinKey_s HE_CKKS_MultipartyRelinKey;
typedef struct HE_CKKS_GaloisKey_s HE_CKKS_GaloisKey;

// --- CKKS RelinKey Functions ---
HE_CKKS_RelinKey* HEonGPU_CKKS_RelinKey_Create(HE_CKKS_Context* context, bool store_in_gpu);
void HEonGPU_CKKS_RelinKey_Delete(HE_CKKS_RelinKey* rk);
HE_CKKS_RelinKey* HEonGPU_CKKS_RelinKey_Clone(const HE_CKKS_RelinKey* other_rk);
int HEonGPU_CKKS_RelinKey_Assign_Copy(HE_CKKS_RelinKey* dest_rk, const HE_CKKS_RelinKey* src_rk);
int HEonGPU_CKKS_RelinKey_Save(HE_CKKS_RelinKey* rk, unsigned char** out_bytes, size_t* out_len);
HE_CKKS_RelinKey* HEonGPU_CKKS_RelinKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, bool store_in_gpu_on_load);

// Getters for RelinKey 
C_scheme_type HEonGPU_CKKS_RelinKey_GetScheme(HE_CKKS_RelinKey* rk);
C_keyswitching_type HEonGPU_CKKS_RelinKey_GetKeyswitchType(HE_CKKS_RelinKey* rk);
int HEonGPU_CKKS_RelinKey_GetRingSize(HE_CKKS_RelinKey* rk); // ring_size_nk
int HEonGPU_CKKS_RelinKey_GetQPrimeSize(HE_CKKS_RelinKey* rk);
int HEonGPU_CKKS_RelinKey_GetQSize(HE_CKKS_RelinKey* rk);
int HEonGPU_CKKS_RelinKey_GetDFactor(HE_CKKS_RelinKey* rk);
bool HEonGPU_CKKS_RelinKey_IsGenerated(HE_CKKS_RelinKey* rk);
C_storage_type HEonGPU_CKKS_RelinKey_GetStorageType(HE_CKKS_RelinKey* rk);
size_t HEonGPU_CKKS_RelinKey_GetData(HE_CKKS_RelinKey* rk, uint64_t* data_buffer, size_t buffer_elements, C_cudaStream_t stream);
int HEonGPU_CKKS_RelinKey_SetData(HE_CKKS_RelinKey* rk, const uint64_t* data_buffer, size_t num_elements, C_cudaStream_t stream);


// --- CKKS MultipartyRelinKey Functions ---
HE_CKKS_MultipartyRelinKey* HEonGPU_CKKS_MultipartyRelinKey_Create(HE_CKKS_Context* context, bool store_in_gpu);
void HEonGPU_CKKS_MultipartyRelinKey_Delete(HE_CKKS_MultipartyRelinKey* mp_rk);
HE_CKKS_MultipartyRelinKey* HEonGPU_CKKS_MultipartyRelinKey_Clone(const HE_CKKS_MultipartyRelinKey* other_mp_rk);
int HEonGPU_CKKS_MultipartyRelinKey_Assign_Copy(HE_CKKS_MultipartyRelinKey* dest_mp_rk, const HE_CKKS_MultipartyRelinKey* src_mp_rk);
int HEonGPU_CKKS_MultipartyRelinKey_Save(HE_CKKS_MultipartyRelinKey* mp_rk, unsigned char** out_bytes, size_t* out_len);
HE_CKKS_MultipartyRelinKey* HEonGPU_CKKS_MultipartyRelinKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, bool store_in_gpu_on_load);

// Getters for MultipartyRelinKey
C_scheme_type HEonGPU_CKKS_MultipartyRelinKey_GetScheme(HE_CKKS_MultipartyRelinKey* mp_rk);
C_keyswitching_type HEonGPU_CKKS_MultipartyRelinKey_GetKeyswitchType(HE_CKKS_MultipartyRelinKey* mp_rk);
int HEonGPU_CKKS_MultipartyRelinKey_GetRingSize(HE_CKKS_MultipartyRelinKey* mp_rk);
int HEonGPU_CKKS_MultipartyRelinKey_GetQPrimeSize(HE_CKKS_MultipartyRelinKey* mp_rk);
int HEonGPU_CKKS_MultipartyRelinKey_GetQSize(HE_CKKS_MultipartyRelinKey* mp_rk);
int HEonGPU_CKKS_MultipartyRelinKey_GetDFactor(HE_CKKS_MultipartyRelinKey* mp_rk);
bool HEonGPU_CKKS_MultipartyRelinKey_IsGenerated(HE_CKKS_MultipartyRelinKey* mp_rk);
C_storage_type HEonGPU_CKKS_MultipartyRelinKey_GetStorageType(HE_CKKS_MultipartyRelinKey* mp_rk);
size_t HEonGPU_CKKS_MultipartyRelinKey_GetData(HE_CKKS_MultipartyRelinKey* mp_rk, uint64_t* data_buffer, size_t buffer_elements, C_cudaStream_t stream);
int HEonGPU_CKKS_MultipartyRelinKey_SetData(HE_CKKS_MultipartyRelinKey* mp_rk, const uint64_t* data_buffer, size_t num_elements, C_cudaStream_t stream);


// --- CKKS GaloisKey Functions ---
HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Create(HE_CKKS_Context* context, const C_RotationIndices_Const_Data* rot_indices, bool store_in_gpu);
void HEonGPU_CKKS_GaloisKey_Delete(HE_CKKS_GaloisKey* gk);
HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Clone(const HE_CKKS_GaloisKey* other_gk);
int HEonGPU_CKKS_GaloisKey_Assign_Copy(HE_CKKS_GaloisKey* dest_gk, const HE_CKKS_GaloisKey* src_gk);
int HEonGPU_CKKS_GaloisKey_Save(HE_CKKS_GaloisKey* gk, unsigned char** out_bytes, size_t* out_len);
HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, const C_RotationIndices_Const_Data* rot_indices_for_reconstruction, bool store_in_gpu_on_load);

// Getters for GaloisKey
C_scheme_type HEonGPU_CKKS_GaloisKey_GetScheme(HE_CKKS_GaloisKey* gk);
C_keyswitching_type HEonGPU_CKKS_GaloisKey_GetKeyswitchType(HE_CKKS_GaloisKey* gk);
int HEonGPU_CKKS_GaloisKey_GetRingSize(HE_CKKS_GaloisKey* gk);
int HEonGPU_CKKS_GaloisKey_GetQPrimeSize(HE_CKKS_GaloisKey* gk);
int HEonGPU_CKKS_GaloisKey_GetQSize(HE_CKKS_GaloisKey* gk);
int HEonGPU_CKKS_GaloisKey_GetDFactor(HE_CKKS_GaloisKey* gk);
bool HEonGPU_CKKS_GaloisKey_IsGenerated(HE_CKKS_GaloisKey* gk);
C_storage_type HEonGPU_CKKS_GaloisKey_GetStorageType(HE_CKKS_GaloisKey* gk);
size_t HEonGPU_CKKS_GaloisKey_GetData(HE_CKKS_GaloisKey* gk, uint64_t* data_buffer, size_t buffer_elements, C_cudaStream_t stream);
int HEonGPU_CKKS_GaloisKey_GetRotationIndices(HE_CKKS_GaloisKey* gk, C_RotationIndices_Data* out_indices_data); // Populates out_indices_data
int HEonGPU_CKKS_GaloisKey_SetData(HE_CKKS_GaloisKey* gk, const uint64_t* data_buffer, size_t num_elements, C_cudaStream_t stream);


#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_EVALUATIONKEY_C_API_H