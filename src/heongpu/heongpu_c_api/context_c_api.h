#ifndef HEONGPU_CONTEXT_C_API_H
#define HEONGPU_CONTEXT_C_API_H

#include <stddef.h> // For size_t
#include <stdint.h> // For uint32_t, uint64_t
#include <stdbool.h> // For bool

// Users will need to cast their actual cudaStream_t to void* when calling.
// Alternatively, include <cuda_runtime_api.h> if all users of this C API will have CUDA toolkit.
typedef void* C_cudaStream_t;

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer type for the CKKS HEContext
typedef struct HE_CKKS_Context_s HE_CKKS_Context;

// From schemes.h
typedef enum {
    C_KEYSWITCHING_NONE = 0,
    C_KEYSWITCHING_METHOD_I = 1, 
    C_KEYSWITCHING_METHOD_II = 2,
    C_KEYSWITCHING_METHOD_III = 3,
    C_KEYSWITCHING_TYPE_INVALID = 0xFF,
} C_keyswitching_type;

// From secstdparams.h
typedef enum {
    C_SEC_LEVEL_TYPE_NONE = 0,
    C_SEC_LEVEL_TYPE_128 = 128,
    C_SEC_LEVEL_TYPE_192 = 192,
    C_SEC_LEVEL_TYPE_256 = 256
} C_sec_level_type;

typedef enum {
    C_STORAGE_TYPE_HOST = 0x1,
    C_STORAGE_TYPE_DEVICE = 0x2,
    C_STORAGE_TYPE_INVALID = 0xFF
} C_storage_type;

typedef enum {
    C_SCHEME_TYPE_NONE = 0x0,
    C_SCHEME_TYPE_BFV = 0x1,
    C_SCHEME_TYPE_CKKS = 0x2,
    C_SCHEME_TYPE_BGV = 0x3
} C_scheme_type;

typedef struct {
    int CtoS_piece;
    int StoC_piece;
    int taylor_number;
    bool less_key_mode;
} C_BootstrappingConfig;

typedef struct {
    C_cudaStream_t stream;
    C_storage_type storage;
    bool keep_initial_condition;
} C_ExecutionOptions;

typedef struct {
    double real;
    double imag;
} C_ComplexDouble;

typedef struct {
    const unsigned char* key_data;
    size_t key_len;
    const unsigned char* nonce_data;
    size_t nonce_len;
    const unsigned char* pstring_data; // Personalization string
    size_t pstring_len;
} C_RNGSeed_Const_Data;

typedef struct {
    unsigned char* key_data;
    size_t key_len;
    unsigned char* nonce_data;
    size_t nonce_len;
    unsigned char* pstring_data; // Personalization string
    size_t pstring_len;
} C_RNGSeed_Data;

typedef struct {
    const int* galois_elements_data;
    size_t galois_elements_len;
    const int* rotation_steps_data;
    size_t rotation_steps_len;
} C_RotationIndices_Const_Data;

typedef struct {
    int* galois_elements_data;
    size_t galois_elements_len;
    int* rotation_steps_data;
    size_t rotation_steps_len;
} C_RotationIndices_Data;



typedef struct {
    uint64_t value; // The modulus value
    uint64_t bit;   // Bit-length of the modulus
    uint64_t mu;    // Barrett reduction constant
} C_Modulus64;


// For Data128 (unsigned __int128), which is not standard in C.
// We can return it as a struct of two uint64_t (high and low parts).
typedef struct {
    uint64_t low;
    uint64_t high;
} C_Data128;


// --- CKKS Context Functions ---
/**
 * @brief Frees the dynamically allocated members within a C_RNGSeed_Data struct.
 * Does not free the struct itself if it was stack-allocated.
 * @param seed_data Pointer to the C_RNGSeed_Data struct whose members are to be freed.
 */
void HEonGPU_Free_C_RNGSeed_Data_Members(C_RNGSeed_Data* seed_data);

/**
 * @brief Frees the dynamically allocated members within a C_RotationIndices_Data struct.
 * Does not free the struct itself if it was stack-allocated.
 * @param indices_data Pointer to the C_RotationIndices_Data struct whose members are to be freed.
 */
void HEonGPU_Free_C_RotationIndices_Data_Members(C_RotationIndices_Data* indices_data);
/**
 * @brief Creates a new CKKS HEContext instance.
 * @param method Integer representing C_keyswitching_type.
 * @param sec_level Integer representing C_sec_level_type (can be a default if C API allows).
 * @return HE_CKKS_Context* Opaque pointer to the created context, or NULL on failure.
 */
HE_CKKS_Context* HEonGPU_CKKS_Context_Create(C_keyswitching_type method,
                                             C_sec_level_type sec_level);

/**
 * @brief Deletes a CKKS HEContext instance and frees its memory.
 * @param context Opaque pointer to the HE_CKKS_Context to delete.
 */
void HEonGPU_CKKS_Context_Delete(HE_CKKS_Context* context);

/**
 * @brief Sets the polynomial modulus degree for the CKKS context.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @param degree The polynomial modulus degree.
 */
void HEonGPU_CKKS_Context_SetPolyModulusDegree(HE_CKKS_Context* context, size_t degree);

/**
 * @brief Sets the coefficient modulus Q and P values for the CKKS context.
 * These are typically arrays of bit-lengths for the primes.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @param log_q_bases_data Pointer to an array of uint64_t representing log Q prime values.
 * @param log_q_bases_len Number of elements in the log_q_bases_data array.
 * @param log_p_bases_data Pointer to an array of uint64_t representing log P prime values.
 * @param log_p_bases_len Number of elements in the log_p_bases_data array.
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Context_SetCoeffModulusValues(HE_CKKS_Context* context,
                                               const uint64_t* log_q_bases_data,
                                               size_t log_q_bases_len,
                                               const uint64_t* log_p_bases_data,
                                               size_t log_p_bases_len);


int HEonGPU_CKKS_Context_SetCoeffModulusBitSizes(HE_CKKS_Context* context,
                                                 const int* log_q_bit_sizes_data,
                                                 size_t log_q_bit_sizes_len,
                                                 const int* log_p_bit_sizes_data,
                                                 size_t log_p_bit_sizes_len);


/**
 * @brief Sets the exact modulus flag for the CKKS context.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @param exact_mod Boolean flag.
 */
void HEonGPU_CKKS_Context_SetExactModulus(HE_CKKS_Context* context, bool exact_mod);


/**
 * @brief Generates/finalizes the parameters for the CKKS context.
 * Must be called after setting all necessary parameters.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Context_Generate(HE_CKKS_Context* context);

/**
 * @brief Gets the polynomial modulus degree from the CKKS context.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @return size_t The polynomial modulus degree, or 0 if context is invalid.
 */
size_t HEonGPU_CKKS_Context_GetPolyModulusDegree(HE_CKKS_Context* context);

/**
 * @brief Gets the number of coefficient moduli (q_i values) in the current context parameters.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @return size_t The number of coefficient moduli.
 */
size_t HEonGPU_CKKS_Context_GetCoeffModulusSize(HE_CKKS_Context* context);

/**
 * @brief Copies the coefficient moduli values into a user-provided buffer.
 * Call HEonGPU_CKKS_Context_GetCoeffModulusSize() first to get the required buffer size.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @param moduli_buffer Pointer to an array of C_Modulus64 to store the moduli.
 * @param buffer_count The size of the moduli_buffer (number of C_Modulus64 elements).
 * @return The number of moduli copied, or 0 on error or if buffer is too small.
 */
size_t HEonGPU_CKKS_Context_GetCoeffModulus(HE_CKKS_Context* context,
                                            C_Modulus64* moduli_buffer,
                                            size_t buffer_count);
// TODO: A function to get a specific modulus by index might also be useful.


void HEonGPU_CKKS_Context_PrintParameters(HE_CKKS_Context* context);


/**
 * @brief Serializes the CKKS context into a byte array.
 * @param context Opaque pointer to the HE_CKKS_Context.
 * @param out_bytes Pointer to a pointer that will be set to the allocated byte array.
 * The caller is responsible for freeing this memory using HEonGPU_FreeSerializedData().
 * @param out_len Pointer to a size_t that will be set to the length of the byte array.
 * @return 0 on success, non-zero on failure.
 */
int HEonGPU_CKKS_Context_Serialize(HE_CKKS_Context* context, unsigned char** out_bytes, size_t* out_len);

/**
 * @brief Deserializes a CKKS context from a byte array.
 * The CUDA stream for the deserialized context will be NULL. It can be set via other means if needed,
 * or a new C API function can be added for this purpose if context's stream needs to be overridden post-load.
 * @param bytes Pointer to the byte array containing the serialized context.
 * @param len Length of the byte array.
 * @param stream CUDA stream to associate with the loaded context (can be NULL).
 * @return HE_CKKS_Context* Opaque pointer to the deserialized context, or NULL on failure.
 */
HE_CKKS_Context* HEonGPU_CKKS_Context_Deserialize(const unsigned char* bytes, size_t len);

/**
 * @brief Frees memory allocated by serialize functions (or other C API functions that allocate).
 * @param data_ptr Pointer to the memory to be freed.
 */
void HEonGPU_FreeSerializedData(void* data_ptr);


#ifdef __cplusplus
} // extern "C"
#endif

#endif // HEONGPU_CONTEXT_C_API_H