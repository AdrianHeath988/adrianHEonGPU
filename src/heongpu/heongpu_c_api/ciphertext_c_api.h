#ifndef HEONGPU_CIPHERTEXT_C_API_H
#define HEONGPU_CIPHERTEXT_C_API_H

#include "context_c_api.h" // For HE_CKKS_Context, C_cudaStream_t, C_storage_type, HEonGPU_FreeSerializedData

#include <stddef.h> // For size_t
#include <stdint.h> // For uint64_t
#include <stdbool.h> 

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer type for the CKKS Ciphertext
typedef struct HE_CKKS_Ciphertext_s HE_CKKS_Ciphertext;

// --- CKKS Ciphertext Lifecycle & Serialization ---

HE_CKKS_Ciphertext* HEonGPU_CKKS_Ciphertext_Create(HE_CKKS_Context* context,
                                                   const C_ExecutionOptions* options); // Takes options

HE_CKKS_Ciphertext* HEonGPU_CKKS_Ciphertext_Load(HE_CKKS_Context* context,
                                                 const unsigned char* bytes,
                                                 size_t len,
                                                 const C_ExecutionOptions* options); // Takes options
                                                   
void HEonGPU_CKKS_Ciphertext_Delete(HE_CKKS_Ciphertext* ciphertext);

HE_CKKS_Ciphertext* HEonGPU_CKKS_Ciphertext_Clone(const HE_CKKS_Ciphertext* other_ciphertext);

int HEonGPU_CKKS_Ciphertext_Assign_Copy(HE_CKKS_Ciphertext* dest_ciphertext,
                                        const HE_CKKS_Ciphertext* src_ciphertext);

int HEonGPU_CKKS_Ciphertext_Save(HE_CKKS_Ciphertext* ciphertext,
                                 unsigned char** out_bytes,
                                 size_t* out_len);

HE_CKKS_Ciphertext* HEonGPU_CKKS_Ciphertext_Set_Scale(HE_CKKS_Ciphertext* ciphertext, double scale);

// --- CKKS Ciphertext Getters ---

/**
 * @brief Gets the ring size (polynomial modulus degree) of the ciphertext.
 * @param ciphertext Opaque pointer to the HE_CKKS_Ciphertext.
 * @return The ring size, or 0 if ciphertext is invalid.
 */
int HEonGPU_CKKS_Ciphertext_GetRingSize(HE_CKKS_Ciphertext* ciphertext);

/**
 * @brief Gets the number of coefficient moduli in the ciphertext's parameters.
 * @param ciphertext Opaque pointer to the HE_CKKS_Ciphertext.
 * @return The number of coefficient moduli, or 0 if ciphertext is invalid.
 */
int HEonGPU_CKKS_Ciphertext_GetCoeffModulusCount(HE_CKKS_Ciphertext* ciphertext);

/**
 * @brief Gets the number of polynomials in the ciphertext (e.g., 2 for a standard ciphertext c0, c1).
 * @param ciphertext Opaque pointer to the HE_CKKS_Ciphertext.
 * @return The number of polynomials, or 0 if ciphertext is invalid.
 */
int HEonGPU_CKKS_Ciphertext_GetCiphertextSize(HE_CKKS_Ciphertext* ciphertext);

/**
 * @brief Gets the scale of the ciphertext.
 * @param ciphertext Opaque pointer to the HE_CKKS_Ciphertext.
 * @return The scale, or a special value (e.g., -1.0 or NaN) if invalid or not applicable.
 */
double HEonGPU_CKKS_Ciphertext_GetScale(HE_CKKS_Ciphertext* ciphertext);

/**
 * @brief Checks if the ciphertext data is in the NTT (Number Theoretic Transform) domain.
 * @param ciphertext Opaque pointer to the HE_CKKS_Ciphertext.
 * @return True if in NTT domain, false otherwise or if ciphertext is invalid.
 */
bool HEonGPU_CKKS_Ciphertext_IsInNttDomain(HE_CKKS_Ciphertext* ciphertext);

/**
 * @brief Gets the current storage type (Host or Device) of the ciphertext data.
 * @param ciphertext Opaque pointer to the HE_CKKS_Ciphertext.
 * @return The C_storage_type enum value, or an indicator of error/invalid.
 */
bool HEonGPU_CKKS_Ciphertext_Is_On_Device(HE_CKKS_Ciphertext* ciphertext);

int HEonGPU_CKKS_Ciphertext_GetDepth(HE_CKKS_Ciphertext* ciphertext);
/**
 * @brief Copies the ciphertext's coefficient data to a user-provided host buffer.
 * The buffer must be large enough to hold all data (ring_size * cipher_size elements).
 * @param ciphertext Opaque pointer to the HE_CKKS_Ciphertext.
 * @param data_buffer User-allocated buffer to copy the data into (as uint64_t).
 * @param buffer_elements The capacity of data_buffer in terms of uint64_t elements.
 * @param stream CUDA stream to use for device-to-host copy if data is on device.
 * @return Number of uint64_t elements copied, or 0 on failure or if buffer is too small.
 */
size_t HEonGPU_CKKS_Ciphertext_GetData(HE_CKKS_Ciphertext* ciphertext,
                                       uint64_t* data_buffer,
                                       size_t buffer_elements,
                                       C_cudaStream_t stream);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_CIPHERTEXT_C_API_H