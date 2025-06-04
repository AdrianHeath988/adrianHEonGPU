#include "evaluationkey_c_api.h"
#include "heongpu.cuh"

#include "ckks/context.cuh"
#include "ckks/evaluationkey.cuh" // The C++ classes we are wrapping
#include "keygeneration.cuh"      // For heongpu::RotationIndices
#include "hostvector.cuh"
#include "schemes.h"
#include "storagemanager.cuh"

#include <vector>
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

// Helper C++ enums to C enums
static C_scheme_type map_cpp_to_c_scheme_type_evk(heongpu::scheme_type cpp_type) {
    switch (cpp_type) {
        case heongpu::scheme_type::none: return C_SCHEME_TYPE_NONE;
        case heongpu::scheme_type::bfv:  return C_SCHEME_TYPE_BFV;
        case heongpu::scheme_type::ckks: return C_SCHEME_TYPE_CKKS;
        case heongpu::scheme_type::bgv:  return C_SCHEME_TYPE_BGV;
        default: return static_cast<C_scheme_type>(-1); 
    }
}

static C_keyswitching_type map_cpp_to_c_keyswitch_type_evk(heongpu::keyswitching_type cpp_type) {
    switch (cpp_type) {
        case heongpu::keyswitching_type::NONE:                 return C_KEYSWITCHING_TYPE_NONE;
        case heongpu::keyswitching_type::KEYSWITCHING_METHOD_I:  return C_KEYSWITCHING_TYPE_METHOD_I;
        case heongpu::keyswitching_type::KEYSWITCHING_METHOD_II: return C_KEYSWITCHING_TYPE_METHOD_II;
        case heongpu::keyswitching_type::KEYSWITCHING_METHOD_III:return C_KEYSWITCHING_TYPE_METHOD_III;
        default: return C_KEYSWITCHING_TYPE_INVALID;
    }
}

static C_storage_type map_cpp_to_c_storage_type_evk(heongpu::storage_type cpp_type) {
    switch (cpp_type) {
        case heongpu::storage_type::HOST:   return C_STORAGE_TYPE_HOST;
        case heongpu::storage_type::DEVICE: return C_STORAGE_TYPE_DEVICE;
        default: return C_STORAGE_TYPE_INVALID;
    }
}


extern "C" {

// --- CKKS RelinKey Functions ---
HE_CKKS_RelinKey* HEonGPU_CKKS_RelinKey_Create(HE_CKKS_Context* context, bool store_in_gpu) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    try {
        auto cpp_obj = new (std::nothrow) heongpu::Relinkey<heongpu::Scheme::CKKS>(*cpp_h_context, store_in_gpu);
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
        cpp_obj = new (std::nothrow) heongpu::Relinkey<heongpu::Scheme::CKKS>(*cpp_h_context, store_in_gpu_on_load);
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

C_scheme_type HEonGPU_CKKS_RelinKey_GetScheme(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) return static_cast<C_scheme_type>(-1);
    try { return map_cpp_to_c_scheme_type_evk(rk->cpp_relinkey->get_scheme()); } catch (...) { return static_cast<C_scheme_type>(-1); }
}
C_keyswitching_type HEonGPU_CKKS_RelinKey_GetKeyswitchType(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) return C_KEYSWITCHING_TYPE_INVALID;
    try { return map_cpp_to_c_keyswitch_type_evk(rk->cpp_relinkey->get_keyswitch_type()); } catch (...) { return C_KEYSWITCHING_TYPE_INVALID; }
}
int HEonGPU_CKKS_RelinKey_GetRingSize(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) return 0;
    try { return rk->cpp_relinkey->ring_size_nk(); } catch (...) { return 0; }
}
int HEonGPU_CKKS_RelinKey_GetQPrimeSize(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) return 0;
    try { return rk->cpp_relinkey->Q_prime_size(); } catch (...) { return 0; }
}
int HEonGPU_CKKS_RelinKey_GetQSize(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) return 0;
    try { return rk->cpp_relinkey->Q_size(); } catch (...) { return 0; }
}
int HEonGPU_CKKS_RelinKey_GetDFactor(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) return 0;
    try { return rk->cpp_relinkey->d_factor(); } catch (...) { return 0; }
}
bool HEonGPU_CKKS_RelinKey_IsGenerated(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) return false;
    try { return rk->cpp_relinkey->is_generated(); } catch (...) { return false; }
}
C_storage_type HEonGPU_CKKS_RelinKey_GetStorageType(HE_CKKS_RelinKey* rk) {
    if (!rk || !rk->cpp_relinkey) return C_STORAGE_TYPE_INVALID;
    try { return map_cpp_to_c_storage_type_evk(rk->cpp_relinkey->get_storage_type()); } catch (...) { return C_STORAGE_TYPE_INVALID; }
}
size_t HEonGPU_CKKS_RelinKey_GetData(HE_CKKS_RelinKey* rk, uint64_t* data_buffer, size_t buffer_elements, C_cudaStream_t stream) {
    if (!rk || !rk->cpp_relinkey || (!data_buffer && buffer_elements > 0)) return 0;
    try {
        heongpu::HostVector<heongpu::Data64> temp_hv;
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream);
        rk->cpp_relinkey->get_data(temp_hv, cpp_stream);
        size_t count = std::min(buffer_elements, temp_hv.size());
        if (count > 0 && data_buffer) std::memcpy(data_buffer, temp_hv.data(), count * sizeof(uint64_t));
        return count;
    } catch (...) { return 0; }
}
int HEonGPU_CKKS_RelinKey_SetData(HE_CKKS_RelinKey* rk, const uint64_t* data_buffer, size_t num_elements, C_cudaStream_t stream) {
    if (!rk || !rk->cpp_relinkey || (!data_buffer && num_elements > 0)) return -1;
    try {
        heongpu::HostVector<heongpu::Data64> input_hv(num_elements);
        if (num_elements > 0 && data_buffer) std::memcpy(input_hv.data(), data_buffer, num_elements * sizeof(uint64_t));
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream);
        rk->cpp_relinkey->set_data(input_hv, cpp_stream);
        return 0;
    } catch (...) { return -2; }
}

// --- CKKS MultipartyRelinKey Functions ---
HE_CKKS_MultipartyRelinKey* HEonGPU_CKKS_MultipartyRelinKey_Create(HE_CKKS_Context* context, bool store_in_gpu) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    try {
        auto cpp_obj = new (std::nothrow) heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>(*cpp_h_context, store_in_gpu);
        if (!cpp_obj) return nullptr;
        auto c_api_obj = new (std::nothrow) HE_CKKS_MultipartyRelinKey_s;
        if (!c_api_obj) { delete cpp_obj; return nullptr; }
        c_api_obj->cpp_mp_relinkey = cpp_obj;
        return c_api_obj;
    } catch (...) { return nullptr; }
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
        cpp_obj = new (std::nothrow) heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>(*cpp_h_context, store_in_gpu_on_load);
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

C_scheme_type HEonGPU_CKKS_MultipartyRelinKey_GetScheme(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return static_cast<C_scheme_type>(-1);
    try { return map_cpp_to_c_scheme_type_evk(mp_rk->cpp_mp_relinkey->get_scheme()); } catch (...) { return static_cast<C_scheme_type>(-1); }
}
C_keyswitching_type HEonGPU_CKKS_MultipartyRelinKey_GetKeyswitchType(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return C_KEYSWITCHING_TYPE_INVALID;
    try { return map_cpp_to_c_keyswitch_type_evk(mp_rk->cpp_mp_relinkey->get_keyswitch_type()); } catch (...) { return C_KEYSWITCHING_TYPE_INVALID; }
}
int HEonGPU_CKKS_MultipartyRelinKey_GetRingSize(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return 0;
    try { return mp_rk->cpp_mp_relinkey->ring_size_nk(); } catch (...) { return 0; }
}
int HEonGPU_CKKS_MultipartyRelinKey_GetQPrimeSize(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return 0;
    try { return mp_rk->cpp_mp_relinkey->Q_prime_size(); } catch (...) { return 0; }
}
int HEonGPU_CKKS_MultipartyRelinKey_GetQSize(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return 0;
    try { return mp_rk->cpp_mp_relinkey->Q_size(); } catch (...) { return 0; }
}
int HEonGPU_CKKS_MultipartyRelinKey_GetDFactor(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return 0;
    try { return mp_rk->cpp_mp_relinkey->d_factor(); } catch (...) { return 0; }
}
bool HEonGPU_CKKS_MultipartyRelinKey_IsGenerated(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return false;
    try { return mp_rk->cpp_mp_relinkey->is_generated(); } catch (...) { return false; }
}
C_storage_type HEonGPU_CKKS_MultipartyRelinKey_GetStorageType(HE_CKKS_MultipartyRelinKey* mp_rk) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey) return C_STORAGE_TYPE_INVALID;
    try { return map_cpp_to_c_storage_type_evk(mp_rk->cpp_mp_relinkey->get_storage_type()); } catch (...) { return C_STORAGE_TYPE_INVALID; }
}
size_t HEonGPU_CKKS_MultipartyRelinKey_GetData(HE_CKKS_MultipartyRelinKey* mp_rk, uint64_t* data_buffer, size_t buffer_elements, C_cudaStream_t stream) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey || (!data_buffer && buffer_elements > 0)) return 0;
    try {
        heongpu::HostVector<heongpu::Data64> temp_hv;
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream);
        mp_rk->cpp_mp_relinkey->get_data(temp_hv, cpp_stream);
        size_t count = std::min(buffer_elements, temp_hv.size());
        if (count > 0 && data_buffer) std::memcpy(data_buffer, temp_hv.data(), count * sizeof(uint64_t));
        return count;
    } catch (...) { return 0; }
}
int HEonGPU_CKKS_MultipartyRelinKey_SetData(HE_CKKS_MultipartyRelinKey* mp_rk, const uint64_t* data_buffer, size_t num_elements, C_cudaStream_t stream) {
    if (!mp_rk || !mp_rk->cpp_mp_relinkey || (!data_buffer && num_elements > 0)) return -1;
    try {
        heongpu::HostVector<heongpu::Data64> input_hv(num_elements);
        if (num_elements > 0 && data_buffer) std::memcpy(input_hv.data(), data_buffer, num_elements * sizeof(uint64_t));
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream);
        mp_rk->cpp_mp_relinkey->set_data(input_hv, cpp_stream);
        return 0;
    } catch (...) { return -2; }
}


// --- CKKS GaloisKey Functions ---
HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Create(HE_CKKS_Context* context, const C_RotationIndices_Const_Data* rot_indices_c, bool store_in_gpu) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context || !rot_indices_c) return nullptr;
    try {
        heongpu::RotationIndices cpp_rot_indices;
        if (rot_indices_c->galois_elements_data && rot_indices_c->galois_elements_len > 0) {
            cpp_rot_indices.galois_elements.assign(rot_indices_c->galois_elements_data, rot_indices_c->galois_elements_data + rot_indices_c->galois_elements_len);
        }
        if (rot_indices_c->rotation_steps_data && rot_indices_c->rotation_steps_len > 0) {
            cpp_rot_indices.rotation_steps.assign(rot_indices_c->rotation_steps_data, rot_indices_c->rotation_steps_data + rot_indices_c->rotation_steps_len);
        }

        auto cpp_obj = new (std::nothrow) heongpu::Galoiskey<heongpu::Scheme::CKKS>(*cpp_h_context, cpp_rot_indices, store_in_gpu);
        if (!cpp_obj) return nullptr;
        auto c_api_obj = new (std::nothrow) HE_CKKS_GaloisKey_s;
        if (!c_api_obj) { delete cpp_obj; return nullptr; }
        c_api_obj->cpp_galoiskey = cpp_obj;
        return c_api_obj;
    } catch (...) { return nullptr; }
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

HE_CKKS_GaloisKey* HEonGPU_CKKS_GaloisKey_Load(HE_CKKS_Context* context, const unsigned char* bytes, size_t len, const C_RotationIndices_Const_Data* rot_indices_for_reconstruction, bool store_in_gpu_on_load) {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_h_context = get_cpp_context(context);
    if (!cpp_h_context) return nullptr;
    if (!bytes && len > 0) return nullptr;
    // RotationIndices are crucial for GaloisKey constructor.
    // If they are part of the serialized stream, this load process needs to match how save works.
    // The C++ load method for Galoiskey in evaluationkey.cu loads rot_indices_ itself.
    // So, for construction before load, we can pass default/empty rot_indices.
    heongpu::RotationIndices temp_rot_indices;
     if (rot_indices_for_reconstruction) { // Use if provided, primarily for clarity if load doesn't fully init this.
        if (rot_indices_for_reconstruction->galois_elements_data && rot_indices_for_reconstruction->galois_elements_len > 0) {
            temp_rot_indices.galois_elements.assign(rot_indices_for_reconstruction->galois_elements_data, rot_indices_for_reconstruction->galois_elements_data + rot_indices_for_reconstruction->galois_elements_len);
        }
        if (rot_indices_for_reconstruction->rotation_steps_data && rot_indices_for_reconstruction->rotation_steps_len > 0) {
            temp_rot_indices.rotation_steps.assign(rot_indices_for_reconstruction->rotation_steps_data, rot_indices_for_reconstruction->rotation_steps_data + rot_indices_for_reconstruction->rotation_steps_len);
        }
    }


    heongpu::Galoiskey<heongpu::Scheme::CKKS>* cpp_obj = nullptr;
    HE_CKKS_GaloisKey* c_api_obj = nullptr;
    try {
        cpp_obj = new (std::nothrow) heongpu::Galoiskey<heongpu::Scheme::CKKS>(*cpp_h_context, temp_rot_indices, store_in_gpu_on_load);
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

C_scheme_type HEonGPU_CKKS_GaloisKey_GetScheme(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return static_cast<C_scheme_type>(-1);
    try { return map_cpp_to_c_scheme_type_evk(gk->cpp_galoiskey->get_scheme()); } catch (...) { return static_cast<C_scheme_type>(-1); }
}
C_keyswitching_type HEonGPU_CKKS_GaloisKey_GetKeyswitchType(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return C_KEYSWITCHING_TYPE_INVALID;
    try { return map_cpp_to_c_keyswitch_type_evk(gk->cpp_galoiskey->get_keyswitch_type()); } catch (...) { return C_KEYSWITCHING_TYPE_INVALID; }
}
int HEonGPU_CKKS_GaloisKey_GetRingSize(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return 0;
    try { return gk->cpp_galoiskey->ring_size_nk(); } catch (...) { return 0; }
}
int HEonGPU_CKKS_GaloisKey_GetQPrimeSize(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return 0;
    try { return gk->cpp_galoiskey->Q_prime_size(); } catch (...) { return 0; }
}
int HEonGPU_CKKS_GaloisKey_GetQSize(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return 0;
    try { return gk->cpp_galoiskey->Q_size(); } catch (...) { return 0; }
}
int HEonGPU_CKKS_GaloisKey_GetDFactor(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return 0;
    try { return gk->cpp_galoiskey->d_factor(); } catch (...) { return 0; }
}
bool HEonGPU_CKKS_GaloisKey_IsGenerated(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return false;
    try { return gk->cpp_galoiskey->is_generated(); } catch (...) { return false; }
}
C_storage_type HEonGPU_CKKS_GaloisKey_GetStorageType(HE_CKKS_GaloisKey* gk) {
    if (!gk || !gk->cpp_galoiskey) return C_STORAGE_TYPE_INVALID;
    try { return map_cpp_to_c_storage_type_evk(gk->cpp_galoiskey->get_storage_type()); } catch (...) { return C_STORAGE_TYPE_INVALID; }
}
size_t HEonGPU_CKKS_GaloisKey_GetData(HE_CKKS_GaloisKey* gk, uint64_t* data_buffer, size_t buffer_elements, C_cudaStream_t stream) {
    if (!gk || !gk->cpp_galoiskey || (!data_buffer && buffer_elements > 0)) return 0;
    try {
        heongpu::HostVector<heongpu::Data64> temp_hv;
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream);
        gk->cpp_galoiskey->get_data(temp_hv, cpp_stream);
        size_t count = std::min(buffer_elements, temp_hv.size());
        if (count > 0 && data_buffer) std::memcpy(data_buffer, temp_hv.data(), count * sizeof(uint64_t));
        return count;
    } catch (...) { return 0; }
}
int HEonGPU_CKKS_GaloisKey_SetData(HE_CKKS_GaloisKey* gk, const uint64_t* data_buffer, size_t num_elements, C_cudaStream_t stream) {
    if (!gk || !gk->cpp_galoiskey || (!data_buffer && num_elements > 0)) return -1;
    try {
        heongpu::HostVector<heongpu::Data64> input_hv(num_elements);
        if (num_elements > 0 && data_buffer) std::memcpy(input_hv.data(), data_buffer, num_elements * sizeof(uint64_t));
        cudaStream_t cpp_stream = static_cast<cudaStream_t>(stream);
        gk->cpp_galoiskey->set_data(input_hv, cpp_stream);
        return 0;
    } catch (...) { return -2; }
}

int HEonGPU_CKKS_GaloisKey_GetRotationIndices(HE_CKKS_GaloisKey* gk, C_RotationIndices_Data* out_indices_data) {
    if (!gk || !gk->cpp_galoiskey || !out_indices_data) return -1;
    
    out_indices_data->galois_elements_data = nullptr; out_indices_data->galois_elements_len = 0;
    out_indices_data->rotation_steps_data = nullptr; out_indices_data->rotation_steps_len = 0;
    try {
        const heongpu::RotationIndices& cpp_indices = gk->cpp_galoiskey->rot_indices();
        if (!cpp_indices.galois_elements.empty()) {
            out_indices_data->galois_elements_len = cpp_indices.galois_elements.size();
            out_indices_data->galois_elements_data = static_cast<int*>(malloc(out_indices_data->galois_elements_len * sizeof(int)));
            if (!out_indices_data->galois_elements_data) { HEonGPU_Free_C_RotationIndices_Data_Members(out_indices_data); return -2; }
            std::memcpy(out_indices_data->galois_elements_data, cpp_indices.galois_elements.data(), out_indices_data->galois_elements_len * sizeof(int));
        }
        if (!cpp_indices.rotation_steps.empty()) {
            out_indices_data->rotation_steps_len = cpp_indices.rotation_steps.size();
            out_indices_data->rotation_steps_data = static_cast<int*>(malloc(out_indices_data->rotation_steps_len * sizeof(int)));
            if (!out_indices_data->rotation_steps_data) { HEonGPU_Free_C_RotationIndices_Data_Members(out_indices_data); return -2; }
            std::memcpy(out_indices_data->rotation_steps_data, cpp_indices.rotation_steps.data(), out_indices_data->rotation_steps_len * sizeof(int));
        }
        return 0; // Success
    } catch (...) { HEonGPU_Free_C_RotationIndices_Data_Members(out_indices_data); return -3; }
}


} // extern "C"