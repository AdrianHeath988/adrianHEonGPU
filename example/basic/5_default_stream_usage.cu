// Copyright 2024-2025 Alişah Özcan
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Developer: Alişah Özcan

#include "heongpu.cuh"
#include "../example_util.h"
#include <omp.h>

// Set up HE Scheme
constexpr auto Scheme = heongpu::Scheme::BFV;

void default_stream_function(
    heongpu::HEContext<Scheme>& context,
    heongpu::HEArithmeticOperator<Scheme>& operators,
    heongpu::Relinkey<Scheme>& relinkeys,
    heongpu::Galoiskey<Scheme>& galoiskeys,
    std::vector<heongpu::Ciphertext<Scheme>>& ciphertext1_in_cpu,
    std::vector<heongpu::Ciphertext<Scheme>>& ciphertext2_in_cpu,
    std::vector<heongpu::Ciphertext<Scheme>>& ciphertext3_in_cpu,
    std::vector<heongpu::Plaintext<Scheme>>& plaintext_in_cpu,
    std::vector<heongpu::Ciphertext<Scheme>>& ciphertext_result_in_gpu,
    int count)
{
    heongpu::Ciphertext<Scheme> temp1(context);
    heongpu::Ciphertext<Scheme> temp2(context);

    for (int i = 0; i < count; i++)
    {
        ciphertext1_in_cpu[i].store_in_device();
        plaintext_in_cpu[i].store_in_device();

        operators.multiply_plain(ciphertext1_in_cpu[i], plaintext_in_cpu[i],
                                 temp1);

        ciphertext2_in_cpu[i].store_in_device();

        operators.sub(temp1, ciphertext2_in_cpu[i], temp2);

        ciphertext3_in_cpu[i].store_in_device();

        operators.multiply_inplace(temp2, ciphertext3_in_cpu[i]);

        operators.relinearize_inplace(temp2, relinkeys);

        operators.add_inplace(temp1, temp2);

        heongpu::Ciphertext<Scheme> result(context);
        operators.rotate_rows(temp1, result, galoiskeys, 5);

        ciphertext_result_in_gpu[i] = std::move(result);
    }
}

int main(int argc, char* argv[])
{
    cudaSetDevice(0); // Use it for memory pool

    // Initialize encryption parameters for the CKKS scheme.
    heongpu::HEContext<Scheme> context(
        heongpu::keyswitching_type::KEYSWITCHING_METHOD_I);

    size_t poly_modulus_degree = 8192;
    int plain_modulus = 786433;
    context.set_poly_modulus_degree(poly_modulus_degree);
    context.set_coeff_modulus_default_values(1);
    context.set_plain_modulus(plain_modulus);
    context.generate();
    context.print_parameters();

    // Generate keys: the public key for encryption, the secret key for
    // decryption, and evaluation keys(relinkey, galoiskey, switchkey).
    heongpu::HEKeyGenerator<Scheme> keygen(context);
    heongpu::Secretkey<Scheme> secret_key(context);
    keygen.generate_secret_key(secret_key);

    heongpu::Publickey<Scheme> public_key(context);
    keygen.generate_public_key(public_key, secret_key);

    heongpu::Relinkey<Scheme> relin_key(context);
    keygen.generate_relin_key(relin_key, secret_key);

    heongpu::Galoiskey<Scheme> galois_key(context);
    keygen.generate_galois_key(galois_key, secret_key);

    heongpu::HEEncoder<Scheme> encoder(context);
    heongpu::HEEncryptor<Scheme> encryptor(context, public_key);
    heongpu::HEArithmeticOperator<Scheme> operators(context, encoder);

    // Assume ciphertexts and plaintexts come from network(from CPU RAM)
    std::cout << "Random ciphertext generetes in CPU... " << std::endl;
    int total_size = 64;
    std::vector<heongpu::Ciphertext<Scheme>> ciphertext1_in_cpu;
    std::vector<heongpu::Ciphertext<Scheme>> ciphertext2_in_cpu;
    std::vector<heongpu::Ciphertext<Scheme>> ciphertext3_in_cpu;
    std::vector<heongpu::Plaintext<Scheme>> plaintext_in_cpu;

    // we know ciphetext and plaintext size
    int cipher_size = 2 * context.get_poly_modulus_degree() *
                      context.get_ciphertext_modulus_count();
    int plain_size = context.get_poly_modulus_degree();

    for (int i = 0; i < total_size; i++)
    {
        std::vector<uint64_t> message1 =
            random_vector_generator(context.get_poly_modulus_degree());
        heongpu::Plaintext<Scheme> P1(context);
        encoder.encode(P1, message1);
        heongpu::Ciphertext<Scheme> C1(context);
        encryptor.encrypt(C1, P1);
        C1.store_in_host();
        ciphertext1_in_cpu.push_back(std::move(C1));

        std::vector<uint64_t> message2 =
            random_vector_generator(context.get_poly_modulus_degree());
        heongpu::Plaintext<Scheme> P2(context);
        encoder.encode(P2, message2);
        heongpu::Ciphertext<Scheme> C2(context);
        encryptor.encrypt(C2, P2);
        C2.store_in_host();
        ciphertext2_in_cpu.push_back(std::move(C2));

        std::vector<uint64_t> message3 =
            random_vector_generator(context.get_poly_modulus_degree());
        heongpu::Plaintext<Scheme> P3(context);
        encoder.encode(P3, message3);
        heongpu::Ciphertext<Scheme> C3(context);
        encryptor.encrypt(C3, P3);
        C3.store_in_host();
        ciphertext3_in_cpu.push_back(std::move(C3));

        std::vector<uint64_t> message4 =
            random_vector_generator(context.get_poly_modulus_degree());
        heongpu::Plaintext<Scheme> P4(context);
        encoder.encode(P4, message4);
        P4.store_in_host();
        plaintext_in_cpu.push_back(std::move(P4));
    }
    std::cout << "Genereted." << std::endl;

    std::cout << "Operations starts..." << std::endl;
    std::vector<heongpu::Ciphertext<Scheme>> results(total_size);
    default_stream_function(context, operators, relin_key, galois_key,
                            ciphertext1_in_cpu, ciphertext2_in_cpu,
                            ciphertext3_in_cpu, plaintext_in_cpu, results,
                            total_size);
    std::cout << "Done." << std::endl;

    std::cout << "To see differece, check streams view with using NVIDIA "
                 "Nsight Systems."
              << std::endl;

    return EXIT_SUCCESS;
}
