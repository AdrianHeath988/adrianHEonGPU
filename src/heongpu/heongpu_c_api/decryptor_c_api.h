#ifndef HEONGPU_DECRYPTOR_C_API_H
#define HEONGPU_DECRYPTOR_C_API_H

#include "context_c_api.h"    // For HE_CKKS_Context, C_ExecutionOptions, C_cudaStream_t
#include "secretkey_c_api.h"  // For HE_CKKS_SecretKey
#include "plaintext_c_api.h"  // For HE_CKKS_Plaintext
#include "ciphertext_c_api.h" // For HE_CKKS_Ciphertext

#include <stddef.h>  // For size_t
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer type for the CKKS HEDecryptor
typedef struct HE_CKKS_Decryptor_s HE_CKKS_Decryptor;

// --- CKKS HEDecryptor Lifecycle ---

/**
 * @brief Creates a new CKKS HEDecryptor instance.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @param sk Opaque pointer to the HE_CKKS_SecretKey.
 * @return HE_CKKS_Decryptor* Opaque pointer to the created decryptor, or NULL on failure.
 */
HE_CKKS_Decryptor* HEonGPU_CKKS_Decryptor_Create(HE_CKKS_Context* context,
                                                 HE_CKKS_SecretKey* sk);

/**
 * @brief Deletes a CKKS HEDecryptor instance and frees its memory.
 * @param decryptor Opaque pointer to the HE_CKKS_Decryptor to delete.
 */
void HEonGPU_CKKS_Decryptor_Delete(HE_CKKS_Decryptor* decryptor);

// --- CKKS Decryption Functions ---

/**
 * @brief Decrypts a ciphertext and stores the result in a pre-allocated plaintext.
 * @param decryptor Opaque pointer to the HE_CKKS_Decryptor.
 * @param pt_out Opaque pointer to an existing HE_CKKS_Plaintext object to store the decryption result.
 * @param ct_in Opaque pointer to the HE_CKKS_Ciphertext to be decrypted.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Decryptor_Decrypt(HE_CKKS_Decryptor* decryptor,
                                   HE_CKKS_Plaintext* pt_out,
                                   HE_CKKS_Ciphertext* ct_in,
                                   const C_ExecutionOptions* options);

// --- Noise Budget Calculation ---

/**
 * @brief Calculates the noise budget of a ciphertext.
 * @param decryptor Opaque pointer to the HE_CKKS_Decryptor.
 * @param ct Opaque pointer to the HE_CKKS_Ciphertext.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return The calculated noise budget in bits, or a negative value on error.
 */
double HEonGPU_CKKS_Decryptor_CalculateNoiseBudget(HE_CKKS_Decryptor* decryptor,
                                                   HE_CKKS_Ciphertext* ct,
                                                   const C_ExecutionOptions* options);

// --- Multiparty Decryption Functions ---

/**
 * @brief Performs partial decryption of a ciphertext using a local secret key share.
 * The result (a partial decryption share) is stored in the provided Plaintext object.
 * @param decryptor Opaque pointer to the HE_CKKS_Decryptor (initialized with a local secret key share).
 * @param partial_pt_out Opaque pointer to an HE_CKKS_Plaintext object to store the partial decryption.
 * @param ct_in Opaque pointer to the HE_CKKS_Ciphertext to be partially decrypted.
 * @param stream CUDA stream for the operation (can be NULL for default).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Decryptor_PartialDecrypt(HE_CKKS_Decryptor* decryptor,
                                          HE_CKKS_Plaintext* partial_pt_out,
                                          HE_CKKS_Ciphertext* ct_in,
                                          C_cudaStream_t stream);

/**
 * @brief Fuses multiple partial decryptions (represented as Ciphertext objects containing specific data)
 * into a final plaintext.
 * @param decryptor Opaque pointer to the HE_CKKS_Decryptor.
 * @param partial_decrypt_shares_array Array of opaque pointers to HE_CKKS_Ciphertext objects,
 * each holding a partial decryption share.
 * @param num_partial_decrypt_shares Number of partial decryption shares in the array.
 * @param final_pt_out Opaque pointer to an HE_CKKS_Plaintext object to store the final decrypted result.
 * @param stream CUDA stream for the operation (can be NULL for default).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Decryptor_DecryptFusion(HE_CKKS_Decryptor* decryptor,
                                         const HE_CKKS_Ciphertext* const* partial_decrypt_shares_array,
                                         size_t num_partial_decrypt_shares,
                                         HE_CKKS_Plaintext* final_pt_out,
                                         C_cudaStream_t stream);

// --- CKKS Decryptor Seed/Offset Management ---
int HEonGPU_CKKS_Decryptor_GetSeed(HE_CKKS_Decryptor* decryptor);
void HEonGPU_CKKS_Decryptor_SetSeed(HE_CKKS_Decryptor* decryptor, int new_seed);
int HEonGPU_CKKS_Decryptor_GetOffset(HE_CKKS_Decryptor* decryptor);
void HEonGPU_CKKS_Decryptor_SetOffset(HE_CKKS_Decryptor* decryptor, int new_offset);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_DECRYPTOR_C_API_H