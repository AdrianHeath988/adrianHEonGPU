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


// --- Multiparty Decryption Functions ---

/**
 * @brief Performs multiparty partial decryption of a ciphertext using a specific party's secret key.
 * The result (a partial decryption share) is stored in the provided output Ciphertext object.
 * This wraps the C++ multi_party_decrypt_partial method.
 * @param decryptor Opaque pointer to the HE_CKKS_Decryptor.
 * @param ct_in Opaque pointer to the HE_CKKS_Ciphertext to be partially decrypted.
 * @param sk_party Opaque pointer to the HE_CKKS_SecretKey of the current party.
 * @param partial_ct_out Opaque pointer to an HE_CKKS_Ciphertext object to store the partial decryption.
 * @param stream_c CUDA stream for the operation (can be NULL for default).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Decryptor_Multiparty_Decrypt_Partial(HE_CKKS_Decryptor* decryptor,
                                                      HE_CKKS_Ciphertext* ct_in,
                                                      HE_CKKS_SecretKey* sk_party,
                                                      HE_CKKS_Ciphertext* partial_ct_out,
                                                      C_cudaStream_t stream_c);

/**
 * @brief Fuses multiple partial decryptions (represented as Ciphertext objects)
 * into a final plaintext using the provided execution options.
 * This wraps the C++ multi_party_decrypt_fusion method.
 * @param decryptor Opaque pointer to the HE_CKKS_Decryptor.
 * @param partial_decrypt_shares_array Array of opaque pointers to HE_CKKS_Ciphertext objects,
 * each holding a partial decryption share.
 * @param num_partial_decrypt_shares Number of partial decryption shares in the array.
 * @param final_pt_out Opaque pointer to an HE_CKKS_Plaintext object to store the final decrypted result.
 * @param options_c Pointer to C_ExecutionOptions (can be NULL for defaults). // MODIFIED PARAMETER
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Decryptor_DecryptFusion(HE_CKKS_Decryptor* decryptor,
                                         const HE_CKKS_Ciphertext* const* partial_decrypt_shares_array,
                                         size_t num_partial_decrypt_shares,
                                         HE_CKKS_Plaintext* final_pt_out,
                                         const C_ExecutionOptions* options_c);

// --- CKKS Decryptor Seed/Offset Management ---
int HEonGPU_CKKS_Decryptor_GetSeed(HE_CKKS_Decryptor* decryptor);
void HEonGPU_CKKS_Decryptor_SetSeed(HE_CKKS_Decryptor* decryptor, int new_seed);
int HEonGPU_CKKS_Decryptor_GetOffset(HE_CKKS_Decryptor* decryptor);
void HEonGPU_CKKS_Decryptor_SetOffset(HE_CKKS_Decryptor* decryptor, int new_offset);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_DECRYPTOR_C_API_H