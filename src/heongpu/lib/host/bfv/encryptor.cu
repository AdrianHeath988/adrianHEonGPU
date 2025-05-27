﻿// Copyright 2024-2025 Alişah Özcan
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Developer: Alişah Özcan

#include "bfv/encryptor.cuh"

namespace heongpu
{
    __host__
    HEEncryptor<Scheme::BFV>::HEEncryptor(HEContext<Scheme::BFV>& context,
                                          Publickey<Scheme::BFV>& public_key)
    {
        if (!context.context_generated_)
        {
            throw std::invalid_argument("HEContext is not generated!");
        }

        scheme_ = context.scheme_;

        std::random_device rd;
        std::mt19937 gen(rd());
        seed_ = gen();
        offset_ = gen();

        if (public_key.storage_type_ == storage_type::DEVICE)
        {
            public_key_ = public_key.device_locations_;
        }
        else
        {
            public_key.store_in_device();
            public_key_ = public_key.device_locations_;
        }

        n = context.n;
        n_power = context.n_power;

        Q_prime_size_ = context.Q_prime_size;
        Q_size_ = context.Q_size;
        P_size_ = context.P_size;

        modulus_ = context.modulus_;

        last_q_modinv_ = context.last_q_modinv_;

        ntt_table_ = context.ntt_table_;
        intt_table_ = context.intt_table_;

        n_inverse_ = context.n_inverse_;

        half_ = context.half_p_;

        half_mod_ = context.half_mod_;

        n = context.n;
        n_power = context.n_power;

        if (scheme_ == scheme_type::bfv)
        {
            plain_modulus_ = context.plain_modulus_;

            Q_mod_t_ = context.Q_mod_t_;

            upper_threshold_ = context.upper_threshold_;

            coeeff_div_plainmod_ = context.coeeff_div_plainmod_;
        }
        else
        {
        }
    }

    __host__ void
    HEEncryptor<Scheme::BFV>::encrypt_bfv(Ciphertext<Scheme::BFV>& ciphertext,
                                          Plaintext<Scheme::BFV>& plaintext,
                                          const cudaStream_t stream)
    {
        DeviceVector<Data64> output_memory((2 * n * Q_size_), stream);

        DeviceVector<Data64> gpu_space(5 * Q_prime_size_ * n, stream);
        Data64* u_poly = gpu_space.data();
        Data64* error_poly = u_poly + (Q_prime_size_ * n);
        Data64* pk_u_poly = error_poly + (2 * Q_prime_size_ * n);

        RandomNumberGenerator::instance()
            .modular_ternary_random_number_generation(
                u_poly, modulus_->data(), n_power, Q_prime_size_, 1, stream);

        RandomNumberGenerator::instance()
            .modular_gaussian_random_number_generation(
                error_std_dev, error_poly, modulus_->data(), n_power,
                Q_prime_size_, 2, stream);

        gpuntt::ntt_rns_configuration<Data64> cfg_ntt = {
            .n_power = n_power,
            .ntt_type = gpuntt::FORWARD,
            .reduction_poly = gpuntt::ReductionPolynomial::X_N_plus,
            .zero_padding = false,
            .stream = stream};

        gpuntt::GPU_NTT_Inplace(u_poly, ntt_table_->data(), modulus_->data(),
                                cfg_ntt, Q_prime_size_, Q_prime_size_);

        pk_u_kernel<<<dim3((n >> 8), Q_prime_size_, 2), 256, 0, stream>>>(
            public_key_.data(), u_poly, pk_u_poly, modulus_->data(), n_power,
            Q_prime_size_);
        HEONGPU_CUDA_CHECK(cudaGetLastError());

        gpuntt::ntt_rns_configuration<Data64> cfg_intt = {
            .n_power = n_power,
            .ntt_type = gpuntt::INVERSE,
            .reduction_poly = gpuntt::ReductionPolynomial::X_N_plus,
            .zero_padding = false,
            .mod_inverse = n_inverse_->data(),
            .stream = stream};

        gpuntt::GPU_NTT_Inplace(pk_u_poly, intt_table_->data(),
                                modulus_->data(), cfg_intt, 2 * Q_prime_size_,
                                Q_prime_size_);

        enc_div_lastq_bfv_kernel<<<dim3((n >> 8), Q_size_, 2), 256, 0,
                                   stream>>>(
            pk_u_poly, error_poly, plaintext.data(), output_memory.data(),
            modulus_->data(), half_->data(), half_mod_->data(),
            last_q_modinv_->data(), plain_modulus_, Q_mod_t_, upper_threshold_,
            coeeff_div_plainmod_->data(), n_power, Q_prime_size_, Q_size_,
            P_size_);
        HEONGPU_CUDA_CHECK(cudaGetLastError());

        ciphertext.memory_set(std::move(output_memory));
    }

} // namespace heongpu