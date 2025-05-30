#ifndef HEONGPU_SERIALIZER_C_API_H
#define HEONGPU_SERIALIZER_C_API_H

#include <stddef.h> // For size_t
#include <stdint.h> // For uint8_t (though unsigned char is often used in C for bytes)


#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Compresses a byte array using zlib.
 * @param input_data Pointer to the input byte array.
 * @param input_len Length of the input byte array.
 * @param output_data Pointer to a pointer that will be set to the allocated compressed byte array.
 * The caller is responsible for freeing this memory using HEonGPU_FreeSerializedData().
 * @param output_len Pointer to a size_t that will be set to the length of the compressed byte array.
 * @return 0 on success, non-zero on failure (e.g., -1 for invalid args, -2 for alloc fail, -3 for compression fail).
 */
int HEonGPU_CompressData(const unsigned char* input_data,
                         size_t input_len,
                         unsigned char** output_data,
                         size_t* output_len);

/**
 * @brief Decompresses a zlib-compressed byte array.
 * @param input_data Pointer to the input compressed byte array.
 * @param input_len Length of the input compressed byte array.
 * @param output_data Pointer to a pointer that will be set to the allocated decompressed byte array.
 * The caller is responsible for freeing this memory using HEonGPU_FreeSerializedData().
 * @param output_len Pointer to a size_t that will be set to the length of the decompressed byte array.
 * @return 0 on success, non-zero on failure (e.g., -1 for invalid args, -2 for alloc fail, -3 for decompression fail).
 */
int HEonGPU_DecompressData(const unsigned char* input_data,
                           size_t input_len,
                           unsigned char** output_data,
                           size_t* output_len);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_SERIALIZER_C_API_H