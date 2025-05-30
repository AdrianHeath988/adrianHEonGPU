#ifndef HEONGPU_PUBLICKEY_C_API_H
#define HEONGPU_PUBLICKEY_C_API_H

#include "context_c_api.h" // For HE_CKKS_Context, C_cudaStream_t, C_storage_type, C_RNGSeed_*, etc.

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer types
typedef struct HE_CKKS_PublicKey_s HE_CKKS_PublicKey;
typedef struct HE_CKKS_MultipartyPublicKey_s HE_CKKS_MultipartyPublicKey;

// --- CKKS PublicKey Functions ---

HE_CKKS_PublicKey* HEonGPU_CKKS_PublicKey_Create(HE_CKKS_Context* context);
void HEonGPU_CKKS_PublicKey_Delete(HE_CKKS_PublicKey* pk);
HE_CKKS_PublicKey* HEonGPU_CKKS_PublicKey_Clone(const HE_CKKS_PublicKey* other_pk);
int HEonGPU_CKKS_PublicKey_Assign_Copy(HE_CKKS_PublicKey* dest_pk, const HE_CKKS_PublicKey* src_pk);

int HEonGPU_CKKS_PublicKey_Save(HE_CKKS_PublicKey* pk, unsigned char** out_bytes, size_t* out_len);
HE_CKKS_PublicKey* HEonGPU_CKKS_PublicKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len);

// Getters for PublicKey
C_scheme_type HEonGPU_CKKS_PublicKey_GetScheme(HE_CKKS_PublicKey* pk);
int HEonGPU_CKKS_PublicKey_GetRingSize(HE_CKKS_PublicKey* pk);
int HEonGPU_CKKS_PublicKey_GetCoeffModulusCount(HE_CKKS_PublicKey* pk);
bool HEonGPU_CKKS_PublicKey_IsInNttDomain(HE_CKKS_PublicKey* pk);
bool HEonGPU_CKKS_PublicKey_IsGenerated(HE_CKKS_PublicKey* pk);
C_storage_type HEonGPU_CKKS_PublicKey_GetStorageType(HE_CKKS_PublicKey* pk);
size_t HEonGPU_CKKS_PublicKey_GetData(HE_CKKS_PublicKey* pk, uint64_t* data_buffer, size_t buffer_elements, C_cudaStream_t stream);

// Setter for PublicKey
int HEonGPU_CKKS_PublicKey_SetData(HE_CKKS_PublicKey* pk, const uint64_t* data_buffer, size_t num_elements, C_cudaStream_t stream);

// --- CKKS MultipartyPublicKey Functions ---

HE_CKKS_MultipartyPublicKey* HEonGPU_CKKS_MultipartyPublicKey_Create(HE_CKKS_Context* context, const C_RNGSeed_Const_Data* seed);
void HEonGPU_CKKS_MultipartyPublicKey_Delete(HE_CKKS_MultipartyPublicKey* mp_pk);
HE_CKKS_MultipartyPublicKey* HEonGPU_CKKS_MultipartyPublicKey_Clone(const HE_CKKS_MultipartyPublicKey* other_mp_pk);
int HEonGPU_CKKS_MultipartyPublicKey_Assign_Copy(HE_CKKS_MultipartyPublicKey* dest_mp_pk, const HE_CKKS_MultipartyPublicKey* src_mp_pk);

int HEonGPU_CKKS_MultipartyPublicKey_Save(HE_CKKS_MultipartyPublicKey* mp_pk, unsigned char** out_bytes, size_t* out_len);
HE_CKKS_MultipartyPublicKey* HEonGPU_CKKS_MultipartyPublicKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, const C_RNGSeed_Const_Data* seed_for_reconstruction); // Seed might be part of serialized data or needed contextually

// Getters for MultipartyPublickey (includes inherited ones, re-wrapped for type safety)
C_scheme_type HEonGPU_CKKS_MultipartyPublicKey_GetScheme(HE_CKKS_MultipartyPublicKey* mp_pk);
int HEonGPU_CKKS_MultipartyPublicKey_GetRingSize(HE_CKKS_MultipartyPublicKey* mp_pk);
int HEonGPU_CKKS_MultipartyPublicKey_GetCoeffModulusCount(HE_CKKS_MultipartyPublicKey* mp_pk);
bool HEonGPU_CKKS_MultipartyPublicKey_IsInNttDomain(HE_CKKS_MultipartyPublicKey* mp_pk);
bool HEonGPU_CKKS_MultipartyPublicKey_IsGenerated(HE_CKKS_MultipartyPublicKey* mp_pk);
C_storage_type HEonGPU_CKKS_MultipartyPublicKey_GetStorageType(HE_CKKS_MultipartyPublicKey* mp_pk);
size_t HEonGPU_CKKS_MultipartyPublicKey_GetData(HE_CKKS_MultipartyPublicKey* mp_pk, uint64_t* data_buffer, size_t buffer_elements, C_cudaStream_t stream);
int HEonGPU_CKKS_MultipartyPublicKey_GetSeed(HE_CKKS_MultipartyPublicKey* mp_pk, C_RNGSeed_Data* out_seed_data); // Populates out_seed_data

// Setter for MultipartyPublickey
int HEonGPU_CKKS_MultipartyPublicKey_SetData(HE_CKKS_MultipartyPublicKey* mp_pk, const uint64_t* data_buffer, size_t num_elements, C_cudaStream_t stream);


#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_PUBLICKEY_C_API_H