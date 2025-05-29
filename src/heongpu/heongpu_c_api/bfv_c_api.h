#ifndef HEONGPU_C_API_H
#define HEONGPU_C_API_H

#include <stddef.h> // For size_t

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer type for the BFV HEContext
typedef struct BFVContext_s BFVContext;

// --- BFV Context Functions ---

/**
 * @brief Creates a new BFV HEContext instance.
 * * @param keyswitch_method_int Integer representing heongpu::keyswitching_type
 * (e.g., 0 for METHOD_I, 1 for METHOD_II - define these mappings)
 * @param poly_modulus_degree The polynomial modulus degree.
 * @param plain_modulus The plaintext modulus.
 * @return BFVContext* Opaque pointer to the created context, or NULL on failure.
 */
BFVContext* HEonGPU_BFV_Context_Create(int keyswitch_method_int, 
                                       size_t poly_modulus_degree, 
                                       int plain_modulus);

/**
 * @brief Generates the parameters for the BFV context.
 * Must be called after setting parameters like poly_modulus_degree.
 * Assumes default coefficient modulus.
 * * @param context Opaque pointer to the BFVContext.
 */
void HEonGPU_BFV_Context_GenerateParams(BFVContext* context);


/**
 * @brief Gets the polynomial modulus degree from the BFV context.
 * * @param context Opaque pointer to the BFVContext.
 * @return size_t The polynomial modulus degree, or 0 if context is invalid.
 */
size_t HEonGPU_BFV_Context_GetPolyModulusDegree(BFVContext* context);

/**
 * @brief Deletes a BFV HEContext instance and frees its memory.
 * * @param context Opaque pointer to the BFVContext to delete.
 */
void HEonGPU_BFV_Context_Delete(BFVContext* context);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_C_API_H