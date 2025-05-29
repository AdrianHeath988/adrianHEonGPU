#include "heongpu_c_api.h"
#include "heongpu.cuh" // Main HEonGPU include, provides access to BFV/CKKS context etc.

// Define the opaque struct BFVContext_s to actually hold the HEonGPU context
// This definition is hidden from the C header users.
struct BFVContext_s {
    heongpu::HEContext<heongpu::Scheme::BFV>* cpp_context;
};

extern "C" {

BFVContext* HEonGPU_BFV_Context_Create(int keyswitch_method_int, 
                                       size_t poly_modulus_degree,
                                       int plain_modulus) {
    try {
        // Map integer to heongpu::keyswitching_type
        // For simplicity, let's assume 0 = METHOD_I, 1 = METHOD_HYBRID (BV), 2 = METHOD_GHS
        // This should be properly documented and managed.
        heongpu::keyswitching_type ks_type;
        switch (keyswitch_method_int) {
            case 0: ks_type = heongpu::keyswitching_type::KEYSWITCHING_METHOD_I; break;
            case 1: ks_type = heongpu::keyswitching_type::KEYSWITCHING_METHOD_HYBRID; break;
            case 2: ks_type = heongpu::keyswitching_type::KEYSWITCHING_METHOD_GHS; break;
            default: return nullptr; // Invalid type
        }

        heongpu::HEContext<heongpu::Scheme::BFV>* cpp_ctx = 
            new heongpu::HEContext<heongpu::Scheme::BFV>(ks_type);

        cpp_ctx->set_poly_modulus_degree(poly_modulus_degree);
        // For BFV, set_coeff_modulus_default_values takes the number of primes.
        // The original README example used 1. Let's stick to that for simplicity for now.
        // A more robust C API might take num_primes as a parameter.
        cpp_ctx->set_coeff_modulus_default_values(1); 
        cpp_ctx->set_plain_modulus(plain_modulus);
        // Note: The 'generate()' from the README example is split into specific setters and
        // a final generate call. Here, we assume parameters are set, and GenerateParams will finalize.

        BFVContext* c_api_context = new BFVContext;
        c_api_context->cpp_context = cpp_ctx;
        return c_api_context;

    } catch (...) {
        // In a real scenario, log the error
        return nullptr;
    }
}

void HEonGPU_BFV_Context_GenerateParams(BFVContext* context) {
    if (context && context->cpp_context) {
        try {
            context->cpp_context->generate();
        } catch (...) {
            // Handle or log error
        }
    }
}

size_t HEonGPU_BFV_Context_GetPolyModulusDegree(BFVContext* context) {
    if (context && context->cpp_context) {
        try {
            return context->cpp_context->get_poly_modulus_degree();
        } catch (...) {
            // Handle or log error
            return 0; 
        }
    }
    return 0; // Invalid context
}

void HEonGPU_BFV_Context_Delete(BFVContext* context) {
    if (context) {
        delete context->cpp_context; // Delete the C++ object
        delete context;             // Delete the C API struct
    }
}

} // extern "C"