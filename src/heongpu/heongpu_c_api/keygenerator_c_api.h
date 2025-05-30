#ifndef HEONGPU_KEYGENERATOR_C_API_H
#define HEONGPU_KEYGENERATOR_C_API_H

#include "context_c_api.h"       // For HE_CKKS_Context, C_ExecutionOptions, C_RNGSeed_Const_Data
#include "secretkey_c_api.h"     // For HE_CKKS_SecretKey
#include "publickey_c_api.h"     // For HE_CKKS_PublicKey, HE_CKKS_MultipartyPublicKey
#include "evaluationkey_c_api.h" // For HE_CKKS_RelinKey, HE_CKKS_MultipartyRelinKey, HE_CKKS_GaloisKey

#include <stddef.h>  // For size_t
#include <stdbool.h> 

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer type for the CKKS HEKeyGenerator
typedef struct HE_CKKS_KeyGenerator_s HE_CKKS_KeyGenerator;

// --- CKKS HEKeyGenerator Lifecycle ---

/**
 * @brief Creates a new CKKS HEKeyGenerator instance.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @return HE_CKKS_KeyGenerator* Opaque pointer to the created key generator, or NULL on failure.
 */
HE_CKKS_KeyGenerator* HEonGPU_CKKS_KeyGenerator_Create(HE_CKKS_Context* context);

/**
 * @brief Deletes a CKKS HEKeyGenerator instance and frees its memory.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator to delete.
 */
void HEonGPU_CKKS_KeyGenerator_Delete(HE_CKKS_KeyGenerator* kg);

// --- Seed Configuration ---

/**
 * @brief Sets the RNG seed for the key generator.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param seed Pointer to the C_RNGSeed_Const_Data containing seed information.
 */
void HEonGPU_CKKS_KeyGenerator_SetSeed(HE_CKKS_KeyGenerator* kg, const C_RNGSeed_Const_Data* seed);

// --- Standard Key Generation ---
// Note: These functions populate pre-created key objects.

/**
 * @brief Generates a secret key.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param sk Opaque pointer to an existing HE_CKKS_SecretKey object to be populated.
 * @param hamming_weight The Hamming weight for the secret key.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_KeyGenerator_GenerateSecretKey(HE_CKKS_KeyGenerator* kg,
                                                HE_CKKS_SecretKey* sk,
                                                int hamming_weight,
                                                const C_ExecutionOptions* options);

/**
 * @brief Generates a public key from a secret key.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param pk Opaque pointer to an existing HE_CKKS_PublicKey object to be populated.
 * @param sk Opaque pointer to the source HE_CKKS_SecretKey.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_KeyGenerator_GeneratePublicKey(HE_CKKS_KeyGenerator* kg,
                                                HE_CKKS_PublicKey* pk,
                                                const HE_CKKS_SecretKey* sk,
                                                const C_ExecutionOptions* options);

/**
 * @brief Generates a relinearization key from a secret key.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param rlk Opaque pointer to an existing HE_CKKS_RelinKey object to be populated.
 * @param sk Opaque pointer to the source HE_CKKS_SecretKey.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_KeyGenerator_GenerateRelinKey(HE_CKKS_KeyGenerator* kg,
                                               HE_CKKS_RelinKey* rlk,
                                               const HE_CKKS_SecretKey* sk,
                                               const C_ExecutionOptions* options);

/**
 * @brief Generates a Galois key from a secret key.
 * The HE_CKKS_GaloisKey object 'gk' must have been created with the desired rotation indices.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param gk Opaque pointer to an existing HE_CKKS_GaloisKey object to be populated.
 * @param sk Opaque pointer to the source HE_CKKS_SecretKey.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_KeyGenerator_GenerateGaloisKey(HE_CKKS_KeyGenerator* kg,
                                                HE_CKKS_GaloisKey* gk,
                                                const HE_CKKS_SecretKey* sk,
                                                const C_ExecutionOptions* options);

// --- Multiparty Key Generation ---

/**
 * @brief Generates a multiparty public key fragment.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param mp_pk Opaque pointer to an existing HE_CKKS_MultipartyPublicKey object to be populated.
 * @param sk Opaque pointer to the local HE_CKKS_SecretKey.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_KeyGenerator_GenerateMultipartyPublicKey(HE_CKKS_KeyGenerator* kg,
                                                          HE_CKKS_MultipartyPublicKey* mp_pk,
                                                          const HE_CKKS_SecretKey* sk,
                                                          const C_ExecutionOptions* options);

/**
 * @brief Generates a multiparty relinearization key fragment.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param mp_rlk Opaque pointer to an existing HE_CKKS_MultipartyRelinKey object to be populated.
 * @param sk Opaque pointer to the local HE_CKKS_SecretKey.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_KeyGenerator_GenerateMultipartyRelinKey(HE_CKKS_KeyGenerator* kg,
                                                         HE_CKKS_MultipartyRelinKey* mp_rlk,
                                                         const HE_CKKS_SecretKey* sk,
                                                         const C_ExecutionOptions* options);

/**
 * @brief Generates a multiparty Galois key fragment.
 * The HE_CKKS_GaloisKey object 'gk' must have been created with the desired rotation indices.
 * Note: The C++ layer uses a Galoiskey object for multiparty scenario as well.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param gk Opaque pointer to an existing HE_CKKS_GaloisKey object to be populated as a multiparty fragment.
 * @param sk Opaque pointer to the local HE_CKKS_SecretKey.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_KeyGenerator_GenerateMultipartyGaloisKey(HE_CKKS_KeyGenerator* kg,
                                                          HE_CKKS_GaloisKey* gk, // Output is a standard GaloisKey
                                                          const HE_CKKS_SecretKey* sk,
                                                          const C_ExecutionOptions* options);

// --- Multiparty Key Aggregation ---

/**
 * @brief Aggregates multiple multiparty public key fragments into a single collective public key.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param public_keys_array Array of opaque pointers to HE_CKKS_MultipartyPublicKey fragments.
 * @param num_public_keys Number of fragments in the array.
 * @param aggregated_pk Opaque pointer to an existing HE_CKKS_PublicKey object to store the aggregated key.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_KeyGenerator_AggregateMultipartyPublicKey(HE_CKKS_KeyGenerator* kg,
                                                           const HE_CKKS_MultipartyPublicKey* const* public_keys_array,
                                                           size_t num_public_keys,
                                                           HE_CKKS_PublicKey* aggregated_pk,
                                                           const C_ExecutionOptions* options);

/**
 * @brief Aggregates multiple multiparty relinearization key fragments.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param relin_keys_array Array of opaque pointers to HE_CKKS_MultipartyRelinKey fragments.
 * @param num_relin_keys Number of fragments in the array.
 * @param aggregated_rlk Opaque pointer to an existing HE_CKKS_RelinKey object to store the aggregated key.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_KeyGenerator_AggregateMultipartyRelinKey(HE_CKKS_KeyGenerator* kg,
                                                          const HE_CKKS_MultipartyRelinKey* const* relin_keys_array,
                                                          size_t num_relin_keys,
                                                          HE_CKKS_RelinKey* aggregated_rlk,
                                                          const C_ExecutionOptions* options);

/**
 * @brief Aggregates multiple multiparty Galois key fragments.
 * @param kg Opaque pointer to the HE_CKKS_KeyGenerator.
 * @param galois_keys_array Array of opaque pointers to HE_CKKS_GaloisKey fragments (used for multiparty).
 * @param num_galois_keys Number of fragments in the array.
 * @param aggregated_gk Opaque pointer to an existing HE_CKKS_GaloisKey object to store the aggregated key.
 * @param options Pointer to C_ExecutionOptions (can be NULL for defaults).
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_KeyGenerator_AggregateMultipartyGaloisKey(HE_CKKS_KeyGenerator* kg,
                                                           const HE_CKKS_GaloisKey* const* galois_keys_array,
                                                           size_t num_galois_keys,
                                                           HE_CKKS_GaloisKey* aggregated_gk,
                                                           const C_ExecutionOptions* options);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_KEYGENERATOR_C_API_H