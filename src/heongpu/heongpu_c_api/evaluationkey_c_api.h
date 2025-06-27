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
typedef struct HE_CKKS_MultipartyGaloisKey_s HE_CKKS_MultipartyGaloisKey;


// --- CKKS RelinKey Functions ---
HE_CKKS_RelinKey* HEonGPU_CKKS_RelinKey_Create(HE_CKKS_Context* context, bool store_in_gpu);
void HEonGPU_CKKS_RelinKey_Delete(HE_CKKS_RelinKey* rk);
HE_CKKS_RelinKey* HEonGPU_CKKS_RelinKey_Clone(const HE_CKKS_RelinKey* other_rk);
int HEonGPU_CKKS_RelinKey_Assign_Copy(HE_CKKS_RelinKey* dest_rk, const HE_CKKS_RelinKey* src_rk);
int HEonGPU_CKKS_RelinKey_Save(HE_CKKS_RelinKey* rk, unsigned char** out_bytes, size_t* out_len);
HE_CKKS_RelinKey* HEonGPU_CKKS_RelinKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, bool store_in_gpu_on_load);

// Getters for RelinKey 
bool HEonGPU_CKKS_RelinKey_IsOnDevice(HE_CKKS_RelinKey* rk);
/**
 * @brief Returns a raw pointer to the entire relinearization key data.
 * @warning The lifetime of this pointer is managed by the RelinKey object. Do not free it.
 * Accessing this pointer after the RelinKey is deleted results in undefined behavior.
 * @param rk Opaque pointer to the HE_CKKS_RelinKey.
 * @return uint64_t* Raw pointer to the key data, or NULL if invalid.
 */
uint64_t* HEonGPU_CKKS_RelinKey_GetDataPointer(HE_CKKS_RelinKey* rk);

/**
 * @brief Returns a raw pointer to a specific part/level of the relinearization key data.
 * @warning The lifetime of this pointer is managed by the RelinKey object. Do not free it.
 * Accessing this pointer after the RelinKey is deleted results in undefined behavior.
 * @param rk Opaque pointer to the HE_CKKS_RelinKey.
 * @param level_index The index of the key level to access.
 * @return uint64_t* Raw pointer to the specified part of the key data, or NULL if invalid.
 */
uint64_t* HEonGPU_CKKS_RelinKey_GetDataPointerForLevel(HE_CKKS_RelinKey* rk, size_t level_index);


// --- CKKS MultipartyRelinKey Functions ---
HE_CKKS_MultipartyRelinKey* HEonGPU_CKKS_MultipartyRelinKey_Create(HE_CKKS_Context* context,const C_RNGSeed_Const_Data* seed, bool store_in_gpu);
void HEonGPU_CKKS_MultipartyRelinKey_Delete(HE_CKKS_MultipartyRelinKey* mp_rk);
HE_CKKS_MultipartyRelinKey* HEonGPU_CKKS_MultipartyRelinKey_Clone(const HE_CKKS_MultipartyRelinKey* other_mp_rk);
int HEonGPU_CKKS_MultipartyRelinKey_Assign_Copy(HE_CKKS_MultipartyRelinKey* dest_mp_rk, const HE_CKKS_MultipartyRelinKey* src_mp_rk);
int HEonGPU_CKKS_MultipartyRelinKey_Save(HE_CKKS_MultipartyRelinKey* mp_rk, unsigned char** out_bytes, size_t* out_len);
HE_CKKS_MultipartyRelinKey* HEonGPU_CKKS_MultipartyRelinKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, bool store_in_gpu_on_load);

// Getters for MultipartyRelinKey
bool HEonGPU_CKKS_MultipartyRelinKey_IsOnDevice(HE_CKKS_MultipartyRelinKey* mp_rk);
uint64_t* HEonGPU_CKKS_MultipartyRelinKey_GetDataPointer(HE_CKKS_MultipartyRelinKey* mp_rk);
uint64_t* HEonGPU_CKKS_MultipartyRelinKey_GetDataPointerForLevel(HE_CKKS_MultipartyRelinKey* mp_rk, size_t level_index);



// --- CKKS GaloisKey Functions ---
HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Create(HE_CKKS_Context* context, bool store_in_gpu);
HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Create_With_Shifts(HE_CKKS_Context* context, int* shift_vec, size_t num_shifts);
void HEonGPU_CKKS_GaloisKey_Delete(HE_CKKS_GaloisKey* gk);
HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Clone(const HE_CKKS_GaloisKey* other_gk);
int HEonGPU_CKKS_GaloisKey_Assign_Copy(HE_CKKS_GaloisKey* dest_gk, const HE_CKKS_GaloisKey* src_gk);
int HEonGPU_CKKS_GaloisKey_Save(HE_CKKS_GaloisKey* gk, unsigned char** out_bytes, size_t* out_len);
HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, bool store_in_gpu_on_load);

// Getters for GaloisKey
bool HEonGPU_CKKS_GaloisKey_IsOnDevice(HE_CKKS_GaloisKey* gk);
uint64_t* HEonGPU_CKKS_GaloisKey_GetDataPointerForLevel(HE_CKKS_GaloisKey* gk, size_t level_index);
uint64_t* HEonGPU_CKKS_GaloisKey_GetDataPointerForColumnRotation(HE_CKKS_GaloisKey* gk);


#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_EVALUATIONKEY_C_API_H