#ifndef HEONGPU_ENCODER_C_API_H
#define HEONGPU_ENCODER_C_API_H

#include "context_c_api.h"   // For HE_CKKS_Context, C_cudaStream_t, C_ComplexDouble
#include "plaintext_c_api.h" // For HE_CKKS_Plaintext

#include <stddef.h>  // For size_t
#include <stdint.h>  // For uint64_t

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer type for the CKKS HEEncoder
typedef struct HE_CKKS_Encoder_s HE_CKKS_Encoder;

// --- CKKS Encoder Lifecycle ---

/**
 * @brief Creates a new CKKS HEEncoder instance.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @return HE_CKKS_Encoder* Opaque pointer to the created encoder, or NULL on failure.
 */
HE_CKKS_Encoder* HEonGPU_CKKS_Encoder_Create(HE_CKKS_Context* context);

/**
 * @brief Deletes a CKKS HEEncoder instance and frees its memory.
 * @param encoder Opaque pointer to the HE_CKKS_Encoder to delete.
 */
void HEonGPU_CKKS_Encoder_Delete(HE_CKKS_Encoder* encoder);

// --- CKKS Encoding Functions ---

/**
 * @brief Encodes a message of double values into a CKKS plaintext.
 * The Plaintext object 'pt' is modified in place.
 * @param encoder Opaque pointer to the HE_CKKS_Encoder.
 * @param pt Opaque pointer to the HE_CKKS_Plaintext to store the encoded result.
 * @param message_data Pointer to an array of doubles representing the message.
 * @param message_len Number of elements in message_data (should match slot count).
 * @param scale The scale to use for encoding.
 * @param stream CUDA stream for the operation.
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Encoder_Encode_Double(HE_CKKS_Encoder* encoder,
                                       HE_CKKS_Plaintext* pt,
                                       const double* message_data,
                                       size_t message_len,
                                       double scale,
                                       C_cudaStream_t stream);

/**
 * @brief Encodes a message of complex double values into a CKKS plaintext.
 * The Plaintext object 'pt' is modified in place.
 * @param encoder Opaque pointer to the HE_CKKS_Encoder.
 * @param pt Opaque pointer to the HE_CKKS_Plaintext to store the encoded result.
 * @param message_data Pointer to an array of C_ComplexDouble structs.
 * @param message_len Number of elements in message_data (should match slot count).
 * @param scale The scale to use for encoding.
 * @param stream CUDA stream for the operation.
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Encoder_Encode_Complex(HE_CKKS_Encoder* encoder,
                                        HE_CKKS_Plaintext* pt,
                                        const C_ComplexDouble* message_data,
                                        size_t message_len,
                                        double scale,
                                        C_cudaStream_t stream);

// --- CKKS Decoding Functions ---

/**
 * @brief Decodes a CKKS plaintext into a message of double values.
 * @param encoder Opaque pointer to the HE_CKKS_Encoder.
 * @param pt Opaque pointer to the HE_CKKS_Plaintext to decode.
 * @param message_buffer User-allocated buffer to store the decoded doubles.
 * @param buffer_len Capacity of message_buffer (should match slot count).
 * @param stream CUDA stream for the operation.
 * @return Number of elements decoded into message_buffer, or a negative value on error.
 * The number of elements should typically be slot_count.
 */
int HEonGPU_CKKS_Encoder_Decode_Double(HE_CKKS_Encoder* encoder,
                                       HE_CKKS_Plaintext* pt,
                                       double* message_buffer,
                                       size_t buffer_len,
                                       C_cudaStream_t stream);

/**
 * @brief Decodes a CKKS plaintext into a message of complex double values.
 * @param encoder Opaque pointer to the HE_CKKS_Encoder.
 * @param pt Opaque pointer to the HE_CKKS_Plaintext to decode.
 * @param message_buffer User-allocated buffer to store the decoded C_ComplexDouble structs.
 * @param buffer_len Capacity of message_buffer (should match slot count).
 * @param stream CUDA stream for the operation.
 * @return Number of elements decoded into message_buffer, or a negative value on error.
 */
int HEonGPU_CKKS_Encoder_Decode_Complex(HE_CKKS_Encoder* encoder,
                                        HE_CKKS_Plaintext* pt,
                                        C_ComplexDouble* message_buffer,
                                        size_t buffer_len,
                                        C_cudaStream_t stream);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_ENCODER_C_API_H