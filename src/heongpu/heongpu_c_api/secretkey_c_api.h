#ifndef HEONGPU_SECRETKEY_C_API_H
#define HEONGPU_SECRETKEY_C_API_H

#include "context_c_api.h" // For HE_CKKS_Context, C_cudaStream_t, C_storage_type, etc.

#include <stddef.h>  // For size_t
#include <stdint.h>  // For uint64_t
#include <stdbool.h> // For bool

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer type for the CKKS SecretKey
typedef struct HE_CKKS_SecretKey_s HE_CKKS_SecretKey;

// --- CKKS SecretKey Lifecycle & Serialization ---

/**
 * @brief Creates a new CKKS SecretKey instance, uninitialized.
 * Key generation is usually handled by HEKeyGenerator.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @return HE_CKKS_SecretKey* Opaque pointer to the created secret key, or NULL on failure.
 */
HE_CKKS_SecretKey* HEonGPU_CKKS_SecretKey_Create(HE_CKKS_Context* context);

/**
 * @brief Deletes a CKKS SecretKey instance and frees its memory.
 * @param sk Opaque pointer to the HE_CKKS_SecretKey to delete.
 */
void HEonGPU_CKKS_SecretKey_Delete(HE_CKKS_SecretKey* sk);

/**
 * @brief Creates a deep copy of an existing CKKS secret key.
 * @param other_sk Opaque pointer to the HE_CKKS_SecretKey to be copied.
 * @return HE_CKKS_SecretKey* Opaque pointer to the new (cloned) secret key, or NULL on failure.
 */
HE_CKKS_SecretKey* HEonGPU_CKKS_SecretKey_Clone(const HE_CKKS_SecretKey* other_sk);

/**
 * @brief Assigns the content of one CKKS secret key to another (deep copy).
 * @param dest_sk Opaque pointer to the destination HE_CKKS_SecretKey.
 * @param src_sk Opaque pointer to the source HE_CKKS_SecretKey.
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_SecretKey_Assign_Copy(HE_CKKS_SecretKey* dest_sk,
                                       const HE_CKKS_SecretKey* src_sk);

/**
 * @brief Serializes the CKKS secret key into a byte array.
 * @param sk Opaque pointer to the HE_CKKS_SecretKey.
 * @param out_bytes Pointer to a pointer that will be set to the allocated byte array.
 * The caller is responsible for freeing this memory using HEonGPU_FreeSerializedData().
 * @param out_len Pointer to a size_t that will be set to the length of the byte array.
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_SecretKey_Save(HE_CKKS_SecretKey* sk,
                                unsigned char** out_bytes,
                                size_t* out_len);

/**
 * @brief Deserializes a CKKS secret key from a byte array.
 * @param context Opaque pointer to the HE_CKKS_Context to associate the new secret key with.
 * @param bytes Pointer to the byte array containing the serialized secret key.
 * @param len Length of the byte array.
 * @return HE_CKKS_SecretKey* Opaque pointer to the deserialized secret key, or NULL on failure.
 */
HE_CKKS_SecretKey* HEonGPU_CKKS_SecretKey_Load(HE_CKKS_Context* context,
                                               const unsigned char* bytes,
                                               size_t len);

// --- CKKS SecretKey Getters ---
C_scheme_type HEonGPU_CKKS_SecretKey_GetScheme(HE_CKKS_SecretKey* sk);
int HEonGPU_CKKS_SecretKey_GetRingSize(HE_CKKS_SecretKey* sk);
int HEonGPU_CKKS_SecretKey_GetCoeffModulusCount(HE_CKKS_SecretKey* sk);
int HEonGPU_CKKS_SecretKey_GetNPower(HE_CKKS_SecretKey* sk);
int HEonGPU_CKKS_SecretKey_GetHammingWeight(HE_CKKS_SecretKey* sk);
bool HEonGPU_CKKS_SecretKey_IsInNttDomain(HE_CKKS_SecretKey* sk);
bool HEonGPU_CKKS_SecretKey_IsGenerated(HE_CKKS_SecretKey* sk);
C_storage_type HEonGPU_CKKS_SecretKey_GetStorageType(HE_CKKS_SecretKey* sk);

/**
 * @brief Copies the secret key's coefficient data to a user-provided host buffer.
 * Buffer must be large enough: ring_size * coeff_modulus_count elements.
 * @param sk Opaque pointer to the HE_CKKS_SecretKey.
 * @param data_buffer User-allocated buffer to copy the data into (as uint64_t).
 * @param buffer_elements The capacity of data_buffer in uint64_t elements.
 * @param stream CUDA stream for device-to-host copy if data is on device.
 * @return Number of uint64_t elements copied, or 0 on failure.
 */
size_t HEonGPU_CKKS_SecretKey_GetData(HE_CKKS_SecretKey* sk,
                                      uint64_t* data_buffer,
                                      size_t buffer_elements,
                                      C_cudaStream_t stream);

// --- CKKS SecretKey Setters ---
/**
 * @brief Sets the data of the secret key from a host buffer.
 * This is typically used after key generation or for loading raw key data.
 * @param sk Opaque pointer to the HE_CKKS_SecretKey.
 * @param data_buffer Buffer containing the secret key data (uint64_t elements).
 * @param num_elements Number of elements in data_buffer. Must match ring_size * coeff_modulus_count.
 * @param stream CUDA stream for host-to-device transfer if applicable.
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_SecretKey_SetData(HE_CKKS_SecretKey* sk,
                                   const uint64_t* data_buffer,
                                   size_t num_elements,
                                   C_cudaStream_t stream);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_SECRETKEY_C_API_H