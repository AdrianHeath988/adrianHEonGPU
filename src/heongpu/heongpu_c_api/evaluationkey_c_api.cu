#include "evaluationkey_c_api.h"
#include "heongpu_c_api_internal.h"
#include "heongpu.cuh"

#include "ckks/context.cuh"
#include "ckks/evaluationkey.cuh" // The C++ classes we are wrapping
#include "ckks/keygenerator.cuh"
#include "keygeneration.cuh"      // For heongpu::RotationIndices
#include "hostvector.cuh"
#include "schemes.h"
#include "storagemanager.cuh"
#include "random.cuh"

#include <vector>
#include <stdint.h>
#include <sstream>
#include <iostream>
#include <algorithm> // For std::min
#include <cstring>   // For std::memcpy
#include <new>       // For std::nothrow

// Define opaque structs

typedef struct HE_CKKS_RelinKey_s HE_CKKS_RelinKey;
typedef struct HE_CKKS_MultipartyRelinKey_s HE_CKKS_MultipartyRelinKey;
typedef struct HE_CKKS_GaloisKey_s HE_CKKS_GaloisKey;


// Helper to safely access underlying C++ HEContext pointer
static heongpu::HEContext<heongpu::Scheme::CKKS>* get_cpp_context(HE_CKKS_Context* context) {
    if (!context || !context->cpp_context) {
        std::cerr << "Error: Invalid HE_CKKS_Context pointer." << std::endl;
        return nullptr;
    }
    return context->cpp_context;
}



extern "C" {

// --- CKKS RelinKey Functions ---
HE_CKKS_RelinKey* HEonGPU_CKKS_RelinKey_Create(HE_CKKS_Context* context, bool store_in_gpu) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    try {
        auto cpp_obj = new (std::nothrow) heongpu::Relinkey<heongpu::Scheme::CKKS>(*cpp_h_context);
        if (!cpp_obj) return nullptr;
        auto c_api_obj = new (std::nothrow) HE_CKKS_RelinKey_s;
        if (!c_api_obj) { delete cpp_obj; return nullptr; }
        c_api_obj->cpp_relinkey = cpp_obj;
        return c_api_obj;
    } catch (...) { return nullptr; }
}

void HEonGPU_CKKS_RelinKey_Delete(HE_CKKS_RelinKey* rk) {
    if (rk) { delete rk->cpp_relinkey; delete rk; }
}

HE_CKKS_RelinKey* HEonGPU_CKKS_RelinKey_Clone(const HE_CKKS_RelinKey* other_rk) {
    if (!other_rk || !other_rk->cpp_relinkey) return nullptr;
    try {
        auto cpp_clone = new (std::nothrow) heongpu::Relinkey<heongpu::Scheme::CKKS>(*(other_rk->cpp_relinkey));
        if (!cpp_clone) return nullptr;
        auto c_api_clone = new (std::nothrow) HE_CKKS_RelinKey_s;
        if (!c_api_clone) { delete cpp_clone; return nullptr; }
        c_api_clone->cpp_relinkey = cpp_clone;
        return c_api_clone;
    } catch (...) { return nullptr; }
}

int HEonGPU_CKKS_RelinKey_Assign_Copy(HE_CKKS_RelinKey* dest_rk, const HE_CKKS_RelinKey* src_rk) {
    if (!dest_rk || !dest_rk->cpp_relinkey || !src_rk || !src_rk->cpp_relinkey) return -1;
    try {
        *(dest_rk->cpp_relinkey) = *(src_rk->cpp_relinkey);
        return 0;
    } catch (...) { return -2; }
}

int HEonGPU_CKKS_RelinKey_Save(HE_CKKS_RelinKey* rk, unsigned char** out_bytes, size_t* out_len) {
    if (!rk || !rk->cpp_relinkey || !out_bytes || !out_len) { if(out_bytes)*out_bytes=nullptr; if(out_len)*out_len=0; return -1; }
    *out_bytes = nullptr; *out_len = 0;
    try {
        std::ostringstream oss(std::ios::binary);
        rk->cpp_relinkey->save(oss);
        std::string str_data = oss.str();
        *out_len = str_data.length();
        if (*out_len > 0) {
            *out_bytes = static_cast<unsigned char*>(malloc(*out_len));
            if (!*out_bytes) { *out_len = 0; std::cerr << "RelinKey_Save: malloc failed\n"; return -2; }
            std::memcpy(*out_bytes, str_data.data(), *out_len);
        }
        return 0;
    } catch (const std::exception& e) { std::cerr << "RelinKey_Save exception: " << e.what() << std::endl; if(*out_bytes){free(*out_bytes); *out_bytes=nullptr;} *out_len=0; return -3; }
      catch (...) { std::cerr << "RelinKey_Save unknown exception" << std::endl; if(*out_bytes){free(*out_bytes);*out_bytes=nullptr;} *out_len=0; return -3; }
}

HE_CKKS_RelinKey* HEonGPU_CKKS_RelinKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, bool store_in_gpu_on_load) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    if (!bytes && len > 0) return nullptr;
    heongpu::Relinkey<heongpu::Scheme::CKKS>* cpp_obj = nullptr;
    HE_CKKS_RelinKey* c_api_obj = nullptr;
    try {
        cpp_obj = new (std::nothrow) heongpu::Relinkey<heongpu::Scheme::CKKS>(*cpp_h_context);
        if (!cpp_obj) return nullptr;
        if (len > 0 && bytes) {
            std::string str_data(reinterpret_cast<const char*>(bytes), len);
            std::istringstream iss(str_data, std::ios::binary);
            cpp_obj->load(iss);
        }
        c_api_obj = new (std::nothrow) HE_CKKS_RelinKey_s;
        if (!c_api_obj) { delete cpp_obj; return nullptr; }
        c_api_obj->cpp_relinkey = cpp_obj;
        return c_api_obj;
    } catch (const std::exception& e) { std::cerr << "RelinKey_Load exception: " << e.what() << std::endl; delete cpp_obj; delete c_api_obj; return nullptr; }
      catch (...) { std::cerr << "RelinKey_Load unknown exception" << std::endl; delete cpp_obj; delete c_api_obj; return nullptr; }
}


bool HEonGPU_CKKS_RelinKey_IsOnDevice(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) return C_STORAGE_TYPE_INVALID;
    try { return (rk->cpp_relinkey->is_on_device()); } catch (...) { return C_STORAGE_TYPE_INVALID; }
}
uint64_t* HEonGPU_CKKS_RelinKey_GetDataPointer(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) {
        std::cerr << "GetDataPointer: Invalid RelinKey pointer." << std::endl;
        return nullptr;
    }
    try {
        // This directly calls the C++ `data()` method. Note: Data64 is uint64_t
        return reinterpret_cast<uint64_t*>(rk->cpp_relinkey->data());
    } catch (const std::exception& e) {
        std::cerr << "GetDataPointer failed with exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "GetDataPointer failed due to an unknown exception." << std::endl;
        return nullptr;
    }
}

uint64_t* HEonGPU_CKKS_RelinKey_GetDataPointerForLevel(HE_CKKS_RelinKey* rk, size_t level_index) {
    if (!rk || !rk->cpp_relinkey) {
        std::cerr << "GetDataPointerForLevel: Invalid RelinKey pointer." << std::endl;
        return nullptr;
    }
    try {
        // This directly calls the C++ `data(size_t)` method.
        return reinterpret_cast<uint64_t*>(rk->cpp_relinkey->data(level_index));
    } catch (const std::exception& e) {
        std::cerr << "GetDataPointerForLevel failed with exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "GetDataPointerForLevel failed due to an unknown exception." << std::endl;
        return nullptr;
    }
}

// --- CKKS MultipartyRelinKey Functions ---
HE_CKKS_MultipartyRelinKey* HEonGPU_CKKS_MultipartyRelinKey_Create(HE_CKKS_Context* context, const C_RNGSeed_Const_Data* seed_c_data, bool store_in_gpu) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) {
        std::cerr << "HEonGPU_CKKS_MultipartyRelinKey_Create failed: Invalid context pointer." << std::endl;
        return nullptr;
    }
    if (!seed_c_data) {
        std::cerr << "HEonGPU_CKKS_MultipartyRelinKey_Create failed: Seed pointer cannot be null." << std::endl;
        return nullptr;
    }

    try {
        // Convert C RNGSeed struct to C++ RNGSeed object
        heongpu::RNGSeed cpp_seed;
        if (seed_c_data->key_data && seed_c_data->key_len > 0) {
            cpp_seed.key_.assign(seed_c_data->key_data, seed_c_data->key_data + seed_c_data->key_len);
        }
        if (seed_c_data->nonce_data && seed_c_data->nonce_len > 0) {
            cpp_seed.nonce_.assign(seed_c_data->nonce_data, seed_c_data->nonce_data + seed_c_data->nonce_len);
        }
        if (seed_c_data->pstring_data && seed_c_data->pstring_len > 0) {
            cpp_seed.personalization_string_.assign(seed_c_data->pstring_data, seed_c_data->pstring_data + seed_c_data->pstring_len);
        }
        
        // Call the C++ constructor with the seed
        auto cpp_obj = new (std::nothrow) heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>(*cpp_h_context, cpp_seed);
        if (!cpp_obj) {
             std::cerr << "HEonGPU_CKKS_MultipartyRelinKey_Create failed: C++ allocation failed." << std::endl;
            return nullptr;
        }

        auto c_api_obj = new (std::nothrow) HE_CKKS_MultipartyRelinKey_s;
        if (!c_api_obj) {
            delete cpp_obj;
            std::cerr << "HEonGPU_CKKS_MultipartyRelinKey_Create failed: C API wrapper allocation failed." << std::endl;
            return nullptr;
        }
        c_api_obj->cpp_mp_relinkey = cpp_obj;
        return c_api_obj;
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_MultipartyRelinKey_Create failed with C++ exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_MultipartyRelinKey_Create failed due to an unknown C++ exception." << std::endl;
        return nullptr;
    }
}

void HEonGPU_CKKS_MultipartyRelinKey_Delete(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (mp_rk) { delete mp_rk->cpp_mp_relinkey; delete mp_rk; }
}

HE_CKKS_MultipartyRelinKey* HEonGPU_CKKS_MultipartyRelinKey_Clone(const HE_CKKS_MultipartyRelinKey* other_mp_rk) {
    if (!other_mp_rk || !other_mp_rk->cpp_mp_relinkey) return nullptr;
    try {
        auto cpp_clone = new (std::nothrow) heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>(*(other_mp_rk->cpp_mp_relinkey));
        if (!cpp_clone) return nullptr;
        auto c_api_clone = new (std::nothrow) HE_CKKS_MultipartyRelinKey_s;
        if (!c_api_clone) { delete cpp_clone; return nullptr; }
        c_api_clone->cpp_mp_relinkey = cpp_clone;
        return c_api_clone;
    } catch (...) { return nullptr; }
}

int HEonGPU_CKKS_MultipartyRelinKey_Assign_Copy(HE_CKKS_MultipartyRelinKey* dest_mp_rk, const HE_CKKS_MultipartyRelinKey* src_mp_rk) {
    if (!dest_mp_rk || !dest_mp_rk->cpp_mp_relinkey || !src_mp_rk || !src_mp_rk->cpp_mp_relinkey) return -1;
    try {
        *(dest_mp_rk->cpp_mp_relinkey) = *(src_mp_rk->cpp_mp_relinkey);
        return 0;
    } catch (...) { return -2; }
}

int HEonGPU_CKKS_MultipartyRelinKey_Save(HE_CKKS_MultipartyRelinKey* mp_rk, unsigned char** out_bytes, size_t* out_len) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey || !out_bytes || !out_len) { if(out_bytes)*out_bytes=nullptr; if(out_len)*out_len=0; return -1; }
    *out_bytes = nullptr; *out_len = 0;
    try {
        std::ostringstream oss(std::ios::binary);
        mp_rk->cpp_mp_relinkey->save(oss);
        std::string str_data = oss.str();
        *out_len = str_data.length();
        if (*out_len > 0) {
            *out_bytes = static_cast<unsigned char*>(malloc(*out_len));
            if (!*out_bytes) { *out_len = 0; return -2; }
            std::memcpy(*out_bytes, str_data.data(), *out_len);
        }
        return 0;
    } catch (...) { if(*out_bytes){free(*out_bytes); *out_bytes=nullptr;} *out_len=0; return -3; }
}

HE_CKKS_MultipartyRelinKey* HEonGPU_CKKS_MultipartyRelinKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, bool store_in_gpu_on_load) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    if (!bytes && len > 0) return nullptr;
    heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>* cpp_obj = nullptr;
    HE_CKKS_MultipartyRelinKey* c_api_obj = nullptr;
    try {
        heongpu::RNGSeed temp_seed;

        cpp_obj = new (std::nothrow) heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>(*cpp_h_context, temp_seed);
        if (!cpp_obj) return nullptr;
        if (len > 0 && bytes) {
            std::string str_data(reinterpret_cast<const char*>(bytes), len);
            std::istringstream iss(str_data, std::ios::binary);
            cpp_obj->load(iss);
        }
        c_api_obj = new (std::nothrow) HE_CKKS_MultipartyRelinKey_s;
        if (!c_api_obj) { delete cpp_obj; return nullptr; }
        c_api_obj->cpp_mp_relinkey = cpp_obj;
        return c_api_obj;
    } catch (...) { delete cpp_obj; delete c_api_obj; return nullptr; }
}


bool HEonGPU_CKKS_MultipartyRelinKey_IsOnDevice(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return C_STORAGE_TYPE_INVALID;
    try { return (mp_rk->cpp_mp_relinkey->is_on_device()); } catch (...) { return C_STORAGE_TYPE_INVALID; }
}
uint64_t* HEonGPU_CKKS_MultipartyRelinKey_GetDataPointer(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return nullptr;
    try { return reinterpret_cast<uint64_t*>(mp_rk->cpp_mp_relinkey->data()); }
    catch (...) { return nullptr; }
}

uint64_t* HEonGPU_CKKS_MultipartyRelinKey_GetDataPointerForLevel(HE_CKKS_MultipartyRelinKey* mp_rk, size_t level_index) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return nullptr;
    try { return reinterpret_cast<uint64_t*>(mp_rk->cpp_mp_relinkey->data(level_index)); }
    catch (...) { return nullptr; }
}


// --- CKKS GaloisKey Functions ---
HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Create(HE_CKKS_Context* context, bool store_in_gpu) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    try {

        auto cpp_obj = new (std::nothrow) heongpu::Galoiskey<heongpu::Scheme::CKKS>(*cpp_h_context);
        if (!cpp_obj) return nullptr;
        auto c_api_obj = new (std::nothrow) HE_CKKS_GaloisKey_s;
        if (!c_api_obj) { delete cpp_obj; return nullptr; }
        c_api_obj->cpp_galoiskey = cpp_obj;
        return c_api_obj;
    } catch (...) { return nullptr; }
}
HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Create_With_Shifts(HE_CKKS_Context* context, int* shift_vec, size_t num_shifts) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) {
        return nullptr;
    }
    // Note: It's valid for shift_vec to be null if num_shifts is 0 (for default keys).

    try {
        std::vector<int> shifts;
        if (shift_vec && num_shifts > 0) {
            shifts.assign(shift_vec, shift_vec + num_shifts);
        }
        auto c_api_obj = new (std::nothrow) HE_CKKS_GaloisKey_s;
        if (!c_api_obj) {
            std::cerr << "GaloisKey_Create_With_Shifts: Failed to allocate C-API wrapper." << std::endl;
            return nullptr;
        }
        c_api_obj->cpp_galoiskey = new (std::nothrow) heongpu::Galoiskey<heongpu::Scheme::CKKS>(*cpp_h_context, shifts);
        if (!c_api_obj->cpp_galoiskey) {
            delete c_api_obj;
            std::cerr << "GaloisKey_Create_With_Shifts: Failed to allocate C++ Galoiskey object." << std::endl;
            return nullptr;
        }
        return c_api_obj;
        
    } catch (const std::exception& e) {
        std::cerr << "HEonGPU_CKKS_GaloisKey_Create_With_Shifts failed with exception: " << e.what() << std::endl;
        return nullptr;
    } catch (...) {
        std::cerr << "HEonGPU_CKKS_GaloisKey_Create_With_Shifts failed with an unknown exception." << std::endl;
        return nullptr;
    }
}
void HEonGPU_CKKS_GaloisKey_Delete(HE_CKKS_GaloisKey* gk) {
    if (gk) { delete gk->cpp_galoiskey; delete gk; }
}

HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Clone(const HE_CKKS_GaloisKey* other_gk) {
    if (!other_gk || !other_gk->cpp_galoiskey) return nullptr;
    try {
        auto cpp_clone = new (std::nothrow) heongpu::Galoiskey<heongpu::Scheme::CKKS>(*(other_gk->cpp_galoiskey));
        if (!cpp_clone) return nullptr;
        auto c_api_clone = new (std::nothrow) HE_CKKS_GaloisKey_s;
        if (!c_api_clone) { delete cpp_clone; return nullptr; }
        c_api_clone->cpp_galoiskey = cpp_clone;
        return c_api_clone;
    } catch (...) { return nullptr; }
}

int HEonGPU_CKKS_GaloisKey_Assign_Copy(HE_CKKS_GaloisKey* dest_gk, const HE_CKKS_GaloisKey* src_gk) {
    if (!dest_gk || !dest_gk->cpp_galoiskey || !src_gk || !src_gk->cpp_galoiskey) return -1;
    try {
        *(dest_gk->cpp_galoiskey) = *(src_gk->cpp_galoiskey);
        return 0;
    } catch (...) { return -2; }
}

int HEonGPU_CKKS_GaloisKey_Save(HE_CKKS_GaloisKey* gk, unsigned char** out_bytes, size_t* out_len) {
    if (!gk || !gk->cpp_galoiskey || !out_bytes || !out_len) { if(out_bytes)*out_bytes=nullptr; if(out_len)*out_len=0; return -1; }
    *out_bytes = nullptr; *out_len = 0;
    try {
        std::ostringstream oss(std::ios::binary);
        gk->cpp_galoiskey->save(oss);
        std::string str_data = oss.str();
        *out_len = str_data.length();
        if (*out_len > 0) {
            *out_bytes = static_cast<unsigned char*>(malloc(*out_len));
            if (!*out_bytes) { *out_len = 0; return -2; }
            std::memcpy(*out_bytes, str_data.data(), *out_len);
        }
        return 0;
    } catch (...) { if(*out_bytes){free(*out_bytes); *out_bytes=nullptr;} *out_len=0; return -3; }
}

HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, bool store_in_gpu_on_load) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    if (!bytes && len > 0) return nullptr;
     


    heongpu::Galoiskey<heongpu::Scheme::CKKS>* cpp_obj = nullptr;
    HE_CKKS_GaloisKey* c_api_obj = nullptr;
    try {
        cpp_obj = new (std::nothrow) heongpu::Galoiskey<heongpu::Scheme::CKKS>(*cpp_h_context);
        if (!cpp_obj) return nullptr;
        if (len > 0 && bytes) {
            std::string str_data(reinterpret_cast<const char*>(bytes), len);
            std::istringstream iss(str_data, std::ios::binary);
            cpp_obj->load(iss); // This should load the actual rot_indices_ from the stream
        }
        c_api_obj = new (std::nothrow) HE_CKKS_GaloisKey_s;
        if (!c_api_obj) { delete cpp_obj; return nullptr; }
        c_api_obj->cpp_galoiskey = cpp_obj;
        return c_api_obj;
    } catch (...) { delete cpp_obj; delete c_api_obj; return nullptr; }
}

bool HEonGPU_CKKS_GaloisKey_IsOnDevice(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return C_STORAGE_TYPE_INVALID;
    try { return (gk->cpp_galoiskey->is_on_device()); } catch (...) { return C_STORAGE_TYPE_INVALID; }
}
uint64_t* HEonGPU_CKKS_GaloisKey_GetDataPointerForLevel(HE_CKKS_GaloisKey* gk, size_t level_index) {
    if (!gk || !gk->cpp_galoiskey) return nullptr;
    try { return reinterpret_cast<uint64_t*>(gk->cpp_galoiskey->data(level_index)); }
    catch (...) { return nullptr; }
}

uint64_t* HEonGPU_CKKS_GaloisKey_GetDataPointerForColumnRotation(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return nullptr;
    try { return reinterpret_cast<uint64_t*>(gk->cpp_galoiskey->c_data()); }
    catch (...) { return nullptr; }
}

} // extern "C"