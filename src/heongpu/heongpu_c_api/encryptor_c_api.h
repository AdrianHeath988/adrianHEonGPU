#ifndef HEONGPU_ENCRYPTOR_C_API_H
#define HEONGPU_ENCRYPTOR_C_API_H

#include "context_c_api.h"    // For HE_CKKS_Context, C_ExecutionOptions
#include "publickey_c_api.h"  // For HE_CKKS_PublicKey
#include "secretkey_c_api.h"  // For HE_CKKS_SecretKey
#include "plaintext_c_api.h"  // For HE_CKKS_Plaintext
#include "ciphertext_c_api.h" // For HE_CKKS_Ciphertext

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer type for the CKKS HEEncryptor
typedef struct HE_CKKS_Encryptor_s HE_CKKS_Encryptor;

// --- CKKS HEEncryptor Lifecycle ---

/**
 * @brief Creates a new CKKS HEEncryptor instance for public key encryption.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @param pk Opaque pointer to the HE_CKKS_PublicKey.
 * @return HE_CKKS_Encryptor* Opaque pointer to the created encryptor, or NULL on failure.
 */
HE_CKKS_Encryptor* HEonGPU_CKKS_Encryptor_Create_With_PublicKey(HE_CKKS_Context* context,
                                                                HE_CKKS_PublicKey* pk);

/**
 * @brief Creates a new CKKS HEEncryptor instance for symmetric key encryption.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @param sk Opaque pointer to the HE_CKKS_SecretKey.
 * @return HE_CKKS_Encryptor* Opaque pointer to the created encryptor, or NULL on failure.
 */
HE_CKKS_Encryptor* HEonGPU_CKKS_Encryptor_Create_With_SecretKey(HE_CKKS_Context* context,
                                                                HE_CKKS_SecretKey* sk);

/**
 * @brief Deletes a CKKS HEEncryptor instance and frees its memory.
 * @param encryptor Opaque pointer to the HE_CKKS_Encryptor to delete.
 */
void HEonGPU_CKKS_Encryptor_Delete(HE_CKKS_Encryptor* encryptor);

// --- CKKS Encryption Functions ---

/**
 * @brief Encrypts a plaintext and stores the result in a pre-allocated ciphertext.
 * @param encryptor Opaque pointer to the HE_CKKS_Encryptor.
 * @param ct_out Opaque pointer to an existing HE_CKKS_Ciphertext object to store the encryption result.
 * @param pt_in Opaque pointer to the HE_CKKS_Plaintext to be encrypted.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Encryptor_Encrypt_To(HE_CKKS_Encryptor* encryptor,
                                      HE_CKKS_Ciphertext* ct_out,
                                      HE_CKKS_Plaintext* pt_in,
                                      const C_ExecutionOptions* options);

/**
 * @brief Encrypts a plaintext and returns a new ciphertext object.
 * @param encryptor Opaque pointer to the HE_CKKS_Encryptor.
 * @param pt_in Opaque pointer to the HE_CKKS_Plaintext to be encrypted.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return HE_CKKS_Ciphertext* Opaque pointer to the newly created and encrypted ciphertext, or NULL on failure.
 * The caller is responsible for deleting the returned ciphertext using HEonGPU_CKKS_Ciphertext_Delete().
 */
HE_CKKS_Ciphertext* HEonGPU_CKKS_Encryptor_Encrypt_New(HE_CKKS_Encryptor* encryptor,
                                                       HE_CKKS_Plaintext* pt_in,
                                                       const C_ExecutionOptions* options);

// --- CKKS Encryptor Seed/Offset Management ---

/**
 * @brief Gets the current seed of the encryptor's PRNG.
 * @param encryptor Opaque pointer to the HE_CKKS_Encryptor.
 * @return The current seed value, or an error indicator if encryptor is invalid.
 */
int HEonGPU_CKKS_Encryptor_GetSeed(HE_CKKS_Encryptor* encryptor);

/**
 * @brief Sets the seed for the encryptor's PRNG.
 * @param encryptor Opaque pointer to the HE_CKKS_Encryptor.
 * @param new_seed The new seed value.
 */
void HEonGPU_CKKS_Encryptor_SetSeed(HE_CKKS_Encryptor* encryptor, int new_seed);

/**
 * @brief Gets the current offset of the encryptor's PRNG.
 * @param encryptor Opaque pointer to the HE_CKKS_Encryptor.
 * @return The current offset value, or an error indicator if encryptor is invalid.
 */
int HEonGPU_CKKS_Encryptor_GetOffset(HE_CKKS_Encryptor* encryptor);

/**
 * @brief Sets the offset for the encryptor's PRNG.
 * @param encryptor Opaque pointer to the HE_CKKS_Encryptor.
 * @param new_offset The new offset value.
 */
void HEonGPU_CKKS_Encryptor_SetOffset(HE_CKKS_Encryptor* encryptor, int new_offset);


#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_ENCRYPTOR_C_API_H