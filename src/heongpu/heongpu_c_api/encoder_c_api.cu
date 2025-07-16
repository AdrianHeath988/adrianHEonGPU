#include "encoder_c_api.h"
#include "heongpu.cuh"
#include "heongpu_c_api_internal.h"
#include "ckks/context.cuh"
#include "ckks/plaintext.cuh"
#include "ckks/encoder.cuh" // The C++ class we are wrapping
#include "hostvector.cuh"
#include "complex.cuh"   // For heongpu::Complex64
#include "schemes.h"     // For heongpu::Data64

#include <vector>
#include <iostream> // For error logging
#include <new>      // For std::nothrow
#include <cuda_runtime.h>
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
// Helper to map C_ExecutionOptions to heongpu::ExecutionOptions
static heongpu::ExecutionOptions map_c_to_cpp_execution_options_enc(const C_ExecutionOptions* c_options) {
    heongpu::ExecutionOptions cpp_options; // Initializes with C++ defaults
    if (c_options) {
        cpp_options.stream_ = static_cast<cudaStream_t>(c_options->stream);
        if (c_options->storage == C_STORAGE_TYPE_HOST) {
            cpp_options.storage_ = heongpu::storage_type::HOST;
        } else if (c_options->storage == C_STORAGE_TYPE_DEVICE) {
            cpp_options.storage_ = heongpu::storage_type::DEVICE;
        }
        // If C_STORAGE_TYPE_INVALID or other, it keeps the C++ default (DEVICE)
        cpp_options.keep_initial_condition_ = c_options->keep_initial_condition;
    }
    return cpp_options;
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
                                       const C_ExecutionOptions* c_options) { // Parameter name matches .h



    // std::cout << "--- Entering HEonGPU_CKKS_Encoder_Encode_Double ---" << std::endl;
    // std::cout << "  encoder: " << encoder << std::endl;
    // std::cout << "  pt: " << pt << std::endl;
    // std::cout << "  message_data address: " << message_data << std::endl;
    // std::cout << "  message_len: " << message_len << std::endl;
    // if (message_data && message_len > 0) {
    //     std::cout << "  message_data contents: [";
    //     for (size_t i = 0; i < 10; ++i) {
    //         std::cout << message_data[i] << (i == message_len - 1 ? "" : ", ");
    //     }
    //     std::cout << "]" << std::endl;
    // } else {
    //     std::cout << "  message_data contents: null or empty" << std::endl;
    // }
    // std::cout << "  scale: " << scale << std::endl;
    // std::cout << "  c_options: " << c_options << std::endl;
    // std::cout << "--------------------------------------------------" << std::endl;


    if (!encoder || !encoder->cpp_encoder || !pt || (message_len > 0 && !message_data)) {
        std::cerr << "Error: Invalid argument(s) to HEonGPU_CKKS_Encoder_Encode_Double." << std::endl;
        return -1; // Error for invalid pointers or message data for non-zero length
    }

    heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_pt = get_cpp_plaintext(pt);
    if (!cpp_pt) {
        return -1; // Error due to invalid plaintext wrapper
    }

    try {
        std::vector<double> cpp_message;
        if (message_len > 0) {
            cpp_message.assign(message_data, message_data + message_len);
        }
        // Else, cpp_message remains empty, which is valid for some encode overloads
        // though the C++ function you provided takes const std::vector<double>& message,
        // so an empty vector will be passed if message_len is 0.

        heongpu::ExecutionOptions cpp_exec_options = map_c_to_cpp_execution_options_enc(c_options);
        
        // Call the C++ encode method that takes std::vector<double> and ExecutionOptions
        encoder->cpp_encoder->encode(*cpp_pt, cpp_message, scale, cpp_exec_options);
        
        

        return 0; // Success
    } catch (const std::invalid_argument& e) { // Catch specific known exceptions if possible
        std::cerr << "HEonGPU_CKKS_Encoder_Encode_Double failed (invalid argument): " << e.what() << std::endl;
        return -3;
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
                                        const C_ExecutionOptions* c_options) {
    if (!encoder || !encoder->cpp_encoder || !pt || !message_data) {
         std::cerr << "Error: Invalid argument(s) to HEonGPU_CKKS_Encoder_Encode_Complex." << std::endl;
        return -1; // Error
    }
    heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_pt = get_cpp_plaintext(pt);
    if (!cpp_pt) return -1;

    try {
        std::vector<Complex64> cpp_message(message_len);
        for (size_t i = 0; i < message_len; ++i) {
            cpp_message[i] = Complex64(message_data[i].real, message_data[i].imag);
        }
        heongpu::ExecutionOptions cpp_exec_options = map_c_to_cpp_execution_options_enc(c_options);
        encoder->cpp_encoder->encode(*cpp_pt, cpp_message, scale, cpp_exec_options);
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
                                       const C_ExecutionOptions* c_options) {
    if (!encoder || !encoder->cpp_encoder || !pt || !message_buffer) {
        std::cerr << "Error: Invalid argument(s) to HEonGPU_CKKS_Encoder_Decode_Double." << std::endl;
        return -1; // Error
    }
    HE_CKKS_Plaintext* pt_clone = HEonGPU_CKKS_Plaintext_Clone(pt);
    heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_pt = get_cpp_plaintext(pt_clone);
    if (!cpp_pt) return -1;

    try {
        // std::cout << "--- Inspecting Raw Plaintext Data ---" << std::endl;
        // uint64_t* device_ptr = HEonGPU_CKKS_Plaintext_GetData(pt_clone);

        // if (!device_ptr) {
        //     std::cerr << "Failed to get plaintext data pointer." << std::endl;
        // }


        // const int values_to_print = 10;
        // std::vector<uint64_t> host_buffer(values_to_print);
        // cudaError_t cuda_status = cudaMemcpy(
        //     host_buffer.data(),                        // Destination (CPU buffer)
        //     device_ptr,                                // Source (GPU pointer)
        //     values_to_print * sizeof(uint64_t),        // Total bytes to copy
        //     cudaMemcpyDeviceToHost                     // Direction of copy
        // );
        // if (cuda_status == cudaSuccess) {
        //     std::cout << "First 10 raw encoded values (from GPU):" << std::endl;
        //     for (int i = 0; i < values_to_print; ++i) {
        //         std::cout << "Value " << i << ": " << host_buffer[i] << std::endl;
        //     }
        // } else {
        //     std::cerr << "cudaMemcpy failed: " << cudaGetErrorString(cuda_status) << std::endl;
        // }

        // std::cout << "------------------------------------" << std::endl;
        // std::cout << "Plaintext Size: " << HEonGPU_CKKS_Plaintext_GetPlainSize(pt_clone) << std::endl;
        // std::cout << "Plaintext Depth: " << HEonGPU_CKKS_Plaintext_GetDepth(pt_clone) << std::endl;
        // std::cout << "Plaintext Scale: " << HEonGPU_CKKS_Plaintext_GetScale(pt_clone) << std::endl;
        // std::cout << "Plaintext is in NTT Domain: " << std::boolalpha << HEonGPU_CKKS_Plaintext_IsInNttDomain(pt_clone) << std::endl;
        // std::cout << "Plaintext is on Device: " << std::boolalpha << HEonGPU_CKKS_Plaintext_IsOnDevice(pt_clone) << std::endl;











        std::vector<double> cpp_message_vec; // HEEncoder::decode_ckks populates this
        heongpu::ExecutionOptions cpp_exec_options = map_c_to_cpp_execution_options_enc(c_options);
        encoder->cpp_encoder->decode(cpp_message_vec, *cpp_pt, cpp_exec_options);

        size_t decoded_len = cpp_message_vec.size();
        size_t elements_to_copy = std::min(buffer_len, decoded_len);
        // std::cout << "--- Debugging Post-Decode ---" << std::endl;
        
        // std::cout << "  Decoded vector size (decoded_len): " << decoded_len << std::endl;
        // std::cout << "  encoder: " << encoder << std::endl;
        // std::cout << "  pt_clone: " << pt_clone << std::endl;
        // std::cout << "  pt: " << pt << std::endl;
        // std::cout << "  Underlying cpp_pt address: " << cpp_pt << std::endl;
        // if (decoded_len > 0) {
        //     std::cout << "  Contents of cpp_message_vec: [";
            
        //     for (int i = 0; i < 10; ++i) {
        //         std::cout << cpp_message_vec[i] << (i == 10 - 1 ? "" : ", ");
        //     }
        //     if (decoded_len > 10) {
        //         std::cout << "...";
        //     }
        //     std::cout << "]" << std::endl;
        // } else {
        //     std::cout << "  cpp_message_vec is empty." << std::endl;
        // }
        // std::cout << "  Destination buffer capacity (buffer_len): " << buffer_len << std::endl;
        // std::cout << "  Elements we will copy: " << elements_to_copy << std::endl;
        // std::cout << "  Destination buffer address (message_buffer): " << (void*)message_buffer << std::endl;
        // std::cout << "  Source vector data address: " << (void*)cpp_message_vec.data() << std::endl;
        


        if (elements_to_copy > 0) {
            std::memcpy(message_buffer, cpp_message_vec.data(), elements_to_copy * sizeof(double));
        }

        // std::cout << "  Check result DECODE:" << std::endl;
        // std::cout <<"  total elements is: " << elements_to_copy << std::endl;
        // std::cout << "  And the buffer is:" <<std::endl;
        // for (int i=0;i<10;i++) {
        //     std::cout << message_buffer[i] << " ";
        // }
        // std::cout << std::endl;
        // std::cout << "-----------------------------" << std::endl;
        

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
                                        const C_ExecutionOptions* c_options) {
    if (!encoder || !encoder->cpp_encoder || !pt || !message_buffer) {
        std::cerr << "Error: Invalid argument(s) to HEonGPU_CKKS_Encoder_Decode_Complex." << std::endl;
        return -1; // Error
    }
    heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_pt = get_cpp_plaintext(pt);
    if (!cpp_pt) return -1;

    try {
        heongpu::HostVector<Complex64> cpp_message_vec;

        heongpu::ExecutionOptions cpp_exec_options = map_c_to_cpp_execution_options_enc(c_options);
        encoder->cpp_encoder->decode(cpp_message_vec, *cpp_pt, cpp_exec_options);

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