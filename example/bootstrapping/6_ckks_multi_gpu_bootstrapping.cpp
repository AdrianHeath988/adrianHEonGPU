// Copyright 2024-2026 Alişah Özcan
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Developer: Alişah Özcan
#include <thread>
#include <chrono>
#include <heongpu/heongpu.hpp>
#include "../example_util.h"

int main(int argc, char* argv[])
{
    // Initialize encryption parameters for the CKKS scheme.
    heongpu::HEContext<heongpu::Scheme::CKKS> context =
        heongpu::GenHEContext<heongpu::Scheme::CKKS>(
            heongpu::sec_level_type::none);
    size_t poly_modulus_degree = 65536;
    context->set_poly_modulus_degree(poly_modulus_degree);

    context->set_coeff_modulus_bit_sizes(
        {60, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50,
         50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50},
        {60, 60, 60});
    context->generate(std::vector<int>{0, 1});
    context->print_parameters();

    // The scale is set to 2^50, resulting in 50 bits of precision before the
    // decimal point.
    double scale = pow(2.0, 50);

    // Generate keys: the public key for encryption, the secret key for
    // decryption and evaluation key(relinkey) for relinearization.
    heongpu::HEKeyGenerator<heongpu::Scheme::CKKS> keygen(context);
    heongpu::Secretkey<heongpu::Scheme::CKKS> secret_key(
        context,
        16); // hamming weight is 16 in this example
    keygen.generate_secret_key(secret_key);

    heongpu::Publickey<heongpu::Scheme::CKKS> public_key(context);
    keygen.generate_public_key(public_key, secret_key);

    heongpu::Relinkey<heongpu::Scheme::CKKS> relin_key(context);
    keygen.generate_relin_key(relin_key, secret_key);

    // Initialize Encoder, Encryptor, Evaluator, and Decryptor. The Encoder will
    // encode the message for SIMD operations. The Encryptor will use the public
    // key to encrypt data, while the Decryptor will use the secret key to
    // decrypt it. The Evaluator will handle operations on the encrypted data.
    heongpu::HEEncoder<heongpu::Scheme::CKKS> encoder(context);
    heongpu::HEEncryptor<heongpu::Scheme::CKKS> encryptor(context, public_key);
    heongpu::HEDecryptor<heongpu::Scheme::CKKS> decryptor(context, secret_key);
    // heongpu::HEOperator operators(context);
    heongpu::HEArithmeticOperator<heongpu::Scheme::CKKS> operators(context,
                                                                   encoder);

    // Generate simple vector in CPU.
    const int slot_count = poly_modulus_degree / 2;
    std::vector<Complex64> message;
    for (int i = 0; i < slot_count; i++)
    {
        message.push_back(Complex64(0.2, 0.4));
    }

    //  Transfer that vector from CPU to GPU and Encode that simple vector in
    //  GPU.
    heongpu::Plaintext<heongpu::Scheme::CKKS> P1(context);
    encoder.encode(P1, message, scale);

    heongpu::Ciphertext<heongpu::Scheme::CKKS> C1(context);
    encryptor.encrypt(C1, P1);
    C1.move_to_device(1); // store ciphertext in GPU, default device is 0

    heongpu::Ciphertext<heongpu::Scheme::CKKS> C2(context);
    encryptor.encrypt(C2, P1);



    // Check README.md for more detail information
    // CtoS_piece_ = [2,5]
    // StoC_piece_ = [2,5]
    // taylor_number_ = [6,15]
    // less_key_mode_ = true or false
    int StoC_piece = 3;
    heongpu::BootstrappingConfig boot_config(3, StoC_piece, 11, true);
    // Generates all bootstrapping parameters before bootstrapping
    operators.generate_bootstrapping_params(
        scale, boot_config,
        heongpu::arithmetic_bootstrapping_type::REGULAR_BOOTSTRAPPING);

    std::vector<int> key_index = operators.bootstrapping_key_indexs();
    std::cout << "Total galois key needed for CKKS bootstrapping: "
              << key_index.size() << std::endl;
    heongpu::Galoiskey<heongpu::Scheme::CKKS> galois_key(context, key_index);

    // Generates all galois key needed for bootstrapping
    keygen.generate_galois_key(galois_key,
                               secret_key); // all galois keys are stored in GPU

    cudaSetDevice(1); 

    // Use the copy constructors to create duplicates on Device 1
    // The copy constructor will allocate VRAM on the current device (1) 
    // and copy the data over the PCIe bus.
    heongpu::Galoiskey<heongpu::Scheme::CKKS> galois_key_dev1 = galois_key;
    heongpu::Relinkey<heongpu::Scheme::CKKS> relin_key_dev1 = relin_key;

    // Switch back to Device 0 for safety before continuing
    cudaSetDevice(0);
    


    // keygen.generate_galois_key(galois_key, secret_key,
    // heongpu::ExecutionOptions().set_storage_type(heongpu::storage_type::HOST));
    // // all galois keys are stored in CPU

    // Drop all level until one level remain
    for (int i = 0; i < 31 - 1; i++)
    {
        operators.mod_drop_inplace(C1);
        operators.mod_drop_inplace(C2);
    }

    std::cout << "Depth before bootstrapping: " << C1.depth() << std::endl;
    heongpu::Ciphertext<heongpu::Scheme::CKKS> cipher_boot;
    heongpu::Ciphertext<heongpu::Scheme::CKKS> cipher_boot2;
    auto start = std::chrono::high_resolution_clock::now();
    // Bootstapping Operation
    std::thread t1([&]() {
        cudaSetDevice(0);
        cipher_boot = operators.regular_bootstrapping(C2, galois_key, relin_key);
    });

    // Launch Device 1 bootstrapping in its own thread
    std::thread t2([&]() {
        cudaSetDevice(1);
        cipher_boot2 = operators.regular_bootstrapping(C1, galois_key_dev1, relin_key_dev1);
    });

    t1.join();
    t2.join();
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    std::cout << "Elapsed time: " << duration.count() << " ms" << std::endl;

    std::cout << "Depth after bootstrapping: " << cipher_boot.depth()
              << std::endl;

    heongpu::Plaintext<heongpu::Scheme::CKKS> P_res1(context);
    decryptor.decrypt(P_res1, cipher_boot);
    std::vector<Complex64> decrypted_1;
    encoder.decode(decrypted_1, P_res1);

    heongpu::Plaintext<heongpu::Scheme::CKKS> P_res2(context);
    decryptor.decrypt(P_res2, cipher_boot2);
    std::vector<Complex64> decrypted_2;
    encoder.decode(decrypted_2, P_res2);

    // Compute and print precision statistics
    heongpu::PrecisionStats prec_stats =
        heongpu::get_precision_stats(message, decrypted_1);

    std::cout << "\n=== Bootstrapping Precision Statistics ===" << std::endl;
    std::cout << prec_stats.to_string() << std::endl;

    // for(int j = 0; j < slot_count; j++){
    for (int j = 0; j < 16; j++)
    {
        std::cout << j << "-> EXPECTED:" << message[j]
                  << " - ACTUAL:" << decrypted_1[j] << std::endl;
    }
    std::cout << std::endl;

    return EXIT_SUCCESS;
}
