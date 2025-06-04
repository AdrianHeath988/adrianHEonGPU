#include "encoder_c_api.h"
#include "heongpu.cuh"

#include "ckks/context.cuh"
#include "ckks/plaintext.cuh"
#include "ckks/encoder.cuh" // The C++ class we are wrapping
#include "hostvector.cuh"
#include "complex.cuh"   // For heongpu::Complex64
#include "schemes.h"     // For heongpu::Data64

#include <vector>
#include <iostream> // For error logging
#include <new>      // For std::nothrow

// Define the opaque struct to hold the actual C++ HEEncoder object

typedef struct HE_CKKS_Encoder_s HE_CKKS_Encoder;

// Helper to safely access underlying C++ pointers from opaque C pointers
static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context(HE_CKKS_Context* context) {
    if (!context || !context->cpp_context) { // Assuming cpp_context from context_c_api.cu
        std::cerr << "Error: Invalid HE_CKKS_Context pointer." << std::endl;
        return nullptr;
    }
    return context->cpp_context;
}

static heongpu::Plaintext<heongpu::Scheme::CKKS>* get_cpp_plaintext(HE_CKKS_Plaintext* pt) {
    if (!pt || !pt->cpp_plaintext) { // Assuming cpp_plaintext from plaintext_c_api.cu
        std::cerr << "Error: Invalid HE_CKKS_Plaintext pointer." << std::endl;
        return nullptr;
    }
    return pt->cpp_plaintext;
}


extern "C" {

// --- CKKS Encoder Lifecycle ---

HE_CKKS_Encoder* HEonGPU_CKKS_Encoder_Create(HE_CKKS_Context* context) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) {
        std::cerr << "HEonGPU_CKKS_Encoder_Create failed: HE_CKKS_Context is null or invalid." << std::endl;
        return nullptr;
    }
    try {
        heongpu::HEEncoder<heongpu::Scheme::CKKS>* cpp_encoder_obj =
            new (std::nothrow) heongpu::HEEncoder<heongpu::Scheme::CKKS>(*cpp_h_context);
        if (!cpp_encoder_obj) {
            std::cerr << "HEonGPU_CKKS_Encoder_Create failed: C++ HEEncoder allocation failed." << std::endl;
            return nullptr;
        }

        HE_CKKS_Encoder* c_api_encoder = new (std::nothrow) HE_CKKS_Encoder_s;
        if (!c_api_encoder) {
            std::cerr << "HEonGPU_CKKS_Encoder_Create failed: C API Encoder wrapper allocation failed." << std::endl;
            delete cpp_encoder_obj;
            return nullptr;
        }
        c_api_encoder->cpp_encoder = cpp_encoder_obj;
        return c_api_encoder;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Encoder_Create failed with C++ exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Encoder_Create failed due to an unknown C++ exception." << std::endl;
        return nullptr;
    }
}

void HEonGPU_CKKS_Encoder_Delete(HE_CKKS_Encoder* encoder) {
    if (encoder) {
        delete encoder->cpp_encoder;
        delete encoder;
    }
}

// --- CKKS Encoding Functions ---

int HEonGPU_CKKS_Encoder_Encode_Double(HE_CKKS_Encoder* encoder,
                                       HE_CKKS_Plaintext* pt,
                                       const double* message_data,
                                       size_t message_len,
                                       double scale,
                                       C_cudaStream_t stream_in) {
    if (!encoder || !encoder->cpp_encoder || !pt || !message_data) {
        std::cerr << "Error: Invalid argument(s) to HEonGPU_CKKS_Encoder_Encode_Double." << std::endl;
        return -1; // Error
    }
    heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_pt = get_cpp_plaintext(pt);
    if (!cpp_pt) return -1;

    try {
        // Convert C array to std::vector<double> or heongpu::HostVector<double>
        // std::vector is fine as HEEncoder has overloads for it.
        std::vector<double> cpp_message(message_data, message_data + message_len);
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream_in);

        encoder->cpp_encoder->encode(*cpp_pt, cpp_message, scale, cpp_stream);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Encoder_Encode_Double failed with C++ exception: " << e.what() << std::endl;
        return -2;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Encoder_Encode_Double failed due to an unknown C++ exception." << std::endl;
        return -2;
    }
}

int HEonGPU_CKKS_Encoder_Encode_Complex(HE_CKKS_Encoder* encoder,
                                        HE_CKKS_Plaintext* pt,
                                        const C_ComplexDouble* message_data,
                                        size_t message_len,
                                        double scale,
                                        C_cudaStream_t stream_in) {
    if (!encoder || !encoder->cpp_encoder || !pt || !message_data) {
         std::cerr << "Error: Invalid argument(s) to HEonGPU_CKKS_Encoder_Encode_Complex." << std::endl;
        return -1; // Error
    }
    heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_pt = get_cpp_plaintext(pt);
    if (!cpp_pt) return -1;

    try {
        std::vector<heongpu::Complex64> cpp_message(message_len);
        for (size_t i = 0; i < message_len; ++i) {
            cpp_message[i] = heongpu::Complex64(message_data[i].real, message_data[i].imag);
        }
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream_in);

        encoder->cpp_encoder->encode(*cpp_pt, cpp_message, scale, cpp_stream);
        return 0; // Success
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Encoder_Encode_Complex failed with C++ exception: " << e.what() << std::endl;
        return -2;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Encoder_Encode_Complex failed due to an unknown C++ exception." << std::endl;
        return -2;
    }
}

// --- CKKS Decoding Functions ---

int HEonGPU_CKKS_Encoder_Decode_Double(HE_CKKS_Encoder* encoder,
                                       HE_CKKS_Plaintext* pt,
                                       double* message_buffer,
                                       size_t buffer_len,
                                       C_cudaStream_t stream_in) {
    if (!encoder || !encoder->cpp_encoder || !pt || !message_buffer) {
        std::cerr << "Error: Invalid argument(s) to HEonGPU_CKKS_Encoder_Decode_Double." << std::endl;
        return -1; // Error
    }
    heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_pt = get_cpp_plaintext(pt);
    if (!cpp_pt) return -1;

    try {
        heongpu::HostVector<double> cpp_message_vec; // HEEncoder::decode_ckks populates this
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream_in);

        encoder->cpp_encoder->decode_ckks(cpp_message_vec, *cpp_pt, cpp_stream);

        size_t decoded_len = cpp_message_vec.size();
        size_t elements_to_copy = std::min(buffer_len, decoded_len);

        if (elements_to_copy > 0) {
            std::memcpy(message_buffer, cpp_message_vec.data(), elements_to_copy * sizeof(double));
        }
        
        if (buffer_len < decoded_len) {
            std::cerr << "Warning: Decode_Double buffer was smaller than decoded message. Truncated." << std::endl;
        }
        return static_cast<int>(elements_to_copy);
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Encoder_Decode_Double failed with C++ exception: " << e.what() << std::endl;
        return -2;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Encoder_Decode_Double failed due to an unknown C++ exception." << std::endl;
        return -2;
    }
}

int HEonGPU_CKKS_Encoder_Decode_Complex(HE_CKKS_Encoder* encoder,
                                        HE_CKKS_Plaintext* pt,
                                        C_ComplexDouble* message_buffer,
                                        size_t buffer_len,
                                        C_cudaStream_t stream_in) {
    if (!encoder || !encoder->cpp_encoder || !pt || !message_buffer) {
        std::cerr << "Error: Invalid argument(s) to HEonGPU_CKKS_Encoder_Decode_Complex." << std::endl;
        return -1; // Error
    }
    heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_pt = get_cpp_plaintext(pt);
    if (!cpp_pt) return -1;

    try {
        heongpu::HostVector<heongpu::Complex64> cpp_message_vec;
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream_in);

        encoder->cpp_encoder->decode_ckks(cpp_message_vec, *cpp_pt, cpp_stream);

        size_t decoded_len = cpp_message_vec.size();
        size_t elements_to_copy = std::min(buffer_len, decoded_len);

        for (size_t i = 0; i < elements_to_copy; ++i) {
            message_buffer[i].real = cpp_message_vec[i].real();
            message_buffer[i].imag = cpp_message_vec[i].imag();
        }
        
        if (buffer_len < decoded_len) {
            std::cerr << "Warning: Decode_Complex buffer was smaller than decoded message. Truncated." << std::endl;
        }
        return static_cast<int>(elements_to_copy);
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_Encoder_Decode_Complex failed with C++ exception: " << e.what() << std::endl;
        return -2;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_Encoder_Decode_Complex failed due to an unknown C++ exception." << std::endl;
        return -2;
    }
}

} // extern "C"