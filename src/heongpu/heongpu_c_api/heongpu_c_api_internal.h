
#ifndef HEONGPU_C_API_INTERNAL_H
#define HEONGPU_C_API_INTERNAL_H
#include "schemes.h"
namespace heongpu {
    template <::heongpu::Scheme S> class HEContext;
    template <::heongpu::Scheme S> class Plaintext;
    template <::heongpu::Scheme S> class Ciphertext;
    template <::heongpu::Scheme S> class Secretkey; 
    template <::heongpu::Scheme S> class Publickey; 
    template <::heongpu::Scheme S> class MultipartyPublickey;
    template <::heongpu::Scheme S> class Relinkey;
    template <::heongpu::Scheme S> class MultipartyRelinkey;
    template <::heongpu::Scheme S> class Galoiskey;
    template <::heongpu::Scheme S> class MultipartyGaloiskey;
    template <::heongpu::Scheme S> class Switchkey;
    template <::heongpu::Scheme S> class HEEncoder;
    template <::heongpu::Scheme S> class HEEncryptor;
    template <::heongpu::Scheme S> class HEDecryptor;
    template <::heongpu::Scheme S> class HEKeyGenerator;
    template <::heongpu::Scheme S> class HEArithmeticOperator;
    template <::heongpu::Scheme S> class HELogicOperator;
} // namespace heongpu



struct HE_CKKS_Context_s {
    heongpu::HEContext<heongpu::Scheme::CKKS>* cpp_context;
};

struct HE_CKKS_Plaintext_s {
    heongpu::Plaintext<heongpu::Scheme::CKKS>* cpp_plaintext;
};

struct HE_CKKS_Ciphertext_s {
    heongpu::Ciphertext<heongpu::Scheme::CKKS>* cpp_ciphertext;
};

struct HE_CKKS_SecretKey_s {
    heongpu::Secretkey<heongpu::Scheme::CKKS>* cpp_secretkey;
};

struct HE_CKKS_PublicKey_s {
    heongpu::Publickey<heongpu::Scheme::CKKS>* cpp_publickey;
};

struct HE_CKKS_MultipartyPublicKey_s {
    heongpu::MultipartyPublickey<heongpu::Scheme::CKKS>* cpp_mp_publickey;
};

struct HE_CKKS_RelinKey_s {
    heongpu::Relinkey<heongpu::Scheme::CKKS>* cpp_relinkey;
};

struct HE_CKKS_MultipartyRelinKey_s {
    heongpu::MultipartyRelinkey<heongpu::Scheme::CKKS>* cpp_mp_relinkey;
};

struct HE_CKKS_GaloisKey_s {
    heongpu::Galoiskey<heongpu::Scheme::CKKS>* cpp_galoiskey;
};

struct HE_CKKS_MultipartyGaloisKey_s {
    heongpu::MultipartyGaloiskey<heongpu::Scheme::CKKS>* cpp_mp_galoiskey;
};

struct HE_CKKS_Encoder_s {
    heongpu::HEEncoder<heongpu::Scheme::CKKS>* cpp_encoder;
};

struct HE_CKKS_Encryptor_s {
    heongpu::HEEncryptor<heongpu::Scheme::CKKS>* cpp_encryptor;
};

struct HE_CKKS_Decryptor_s {
    heongpu::HEDecryptor<heongpu::Scheme::CKKS>* cpp_decryptor;
};

struct HE_CKKS_KeyGenerator_s {
    heongpu::HEKeyGenerator<heongpu::Scheme::CKKS>* cpp_keygen;
};

struct HE_CKKS_ArithmeticOperator_s {
    heongpu::HEArithmeticOperator<heongpu::Scheme::CKKS>* cpp_arith_op;
};

struct HE_CKKS_LogicOperator_s {
    heongpu::HELogicOperator<heongpu::Scheme::CKKS>* cpp_logic_op;
};

#endif // HEONGPU_C_API_INTERNAL_H