#include "serializer_c_api.h"
#include "util/serializer.h" // For heongpu::serializer::compress and ::decompress

#include <vector>
#include <iostream> // For error logging
#include <new>      // For std::nothrow
#include <cstring>  // For std::memcpy
#include <cstdlib>  // For malloc, free


extern "C" {

int HEonGPU_CompressData(const unsigned char* input_data,
                         size_t input_len,
                         unsigned char** output_data,
                         size_t* output_len) {
    if (!input_data || !output_data || !output_len) {
        if (output_data) *output_data = nullptr;
        if (output_len) *output_len = 0;
        return -1; // Invalid arguments
    }
    *output_data = nullptr;
    *output_len = 0;

    if (input_len == 0) {
        return 0; // Success, empty input results in empty output
    }

    try {
        std::vector<uint8_t> cpp_input_data(input_data, input_data + input_len);
        std::vector<uint8_t> cpp_output_data = heongpu::serializer::compress(cpp_input_data);

        *output_len = cpp_output_data.size();
        if (*output_len == 0 && input_len > 0) {
             *output_data = nullptr;
            return 0;
        }
        if (*output_len > 0) {
            *output_data = static_cast<unsigned char*>(malloc(*output_len));
            if (!(*output_data)) {
                *output_len = 0;
                std::cerr << "HEonGPU_CompressData failed: Memory allocation error." << std::endl;
                return -2; // Memory allocation failed
            }
            std::memcpy(*output_data, cpp_output_data.data(), *output_len);
        }
        return 0; // Success

    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CompressData failed with C++ exception: " << e.what() << std::endl;
        if (*output_data) { free(*output_data); *output_data = nullptr; }
        *output_len = 0;
        return -3; // Compression failed
    } catch (...) {
        std::cerr << "HEonGPU_CompressData failed due to an unknown C++ exception." << std::endl;
        if (*output_data) { free(*output_data); *output_data = nullptr; }
        *output_len = 0;
        return -3;
    }
}

int HEonGPU_DecompressData(const unsigned char* input_data,
                           size_t input_len,
                           unsigned char** output_data,
                           size_t* output_len) {
    if (!input_data || !output_data || !output_len) {
        if (output_data) *output_data = nullptr;
        if (output_len) *output_len = 0;
        return -1; // Invalid arguments
    }
    *output_data = nullptr;
    *output_len = 0;

    if (input_len == 0) {
        // Depending on zlib, decompressing empty might be an error or result in empty.
        // heongpu::serializer::decompress might throw for empty input.
        // Let's assume valid compressed data is non-empty.
        std::cerr << "HEonGPU_DecompressData failed: Input data length is zero." << std::endl;
        return -1; 
    }

    try {
        std::vector<uint8_t> cpp_input_data(input_data, input_data + input_len);
        std::vector<uint8_t> cpp_output_data = heongpu::serializer::decompress(cpp_input_data);

        *output_len = cpp_output_data.size();
         if (*output_len == 0 && input_len > 0) { 
            // This could happen if decompression of valid (but perhaps minimal) input yields empty data.
            *output_data = nullptr;
            return 0; 
        }
        if (*output_len > 0) {
            *output_data = static_cast<unsigned char*>(malloc(*output_len));
            if (!(*output_data)) {
                *output_len = 0;
                std::cerr << "HEonGPU_DecompressData failed: Memory allocation error." << std::endl;
                return -2; // Memory allocation failed
            }
            std::memcpy(*output_data, cpp_output_data.data(), *output_len);
        }
        return 0; // Success

    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_DecompressData failed with C++ exception: " << e.what() << std::endl;
        if (*output_data) { free(*output_data); *output_data = nullptr; }
        *output_len = 0;
        return -3; // Decompression failed
    } catch (...) {
        std::cerr << "HEonGPU_DecompressData failed due to an unknown C++ exception." << std::endl;
        if (*output_data) { free(*output_data); *output_data = nullptr; }
        *output_len = 0;
        return -3;
    }
}

} // extern "C"