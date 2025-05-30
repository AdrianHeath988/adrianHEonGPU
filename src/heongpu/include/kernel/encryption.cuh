﻿// Copyright 2024-2025 Alişah Özcan
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Developer: Alişah Özcan

#ifndef HEONGPU_ENCRYPTION_H
#define HEONGPU_ENCRYPTION_H

#include "common.cuh"
#include "cuda_runtime.h"
#include "modular_arith.cuh"
#include <curand_kernel.h>
#include "util.cuh"

namespace heongpu
{
    __global__ void pk_u_kernel(Data64* pk, Data64* u, Data64* pk_u,
                                Modulus64* modulus, int n_power,
                                int rns_mod_count);

    __global__ void
    enc_div_lastq_bfv_kernel(Data64* pk, Data64* e, Data64* plain, Data64* ct,
                             Modulus64* modulus, Data64* half, Data64* half_mod,
                             Data64* last_q_modinv, Modulus64 plain_mod,
                             Data64 Q_mod_t, Data64 upper_threshold,
                             Data64* coeffdiv_plain, int n_power,
                             int Q_prime_size, int Q_size, int P_size);

    __global__ void enc_div_lastq_ckks_kernel(Data64* pk, Data64* e, Data64* ct,
                                              Modulus64* modulus, Data64* half,
                                              Data64* half_mod,
                                              Data64* last_q_modinv,
                                              int n_power, int Q_prime_size,
                                              int Q_size, int P_size);

    __global__ void cipher_message_add_kernel(Data64* ciphertext,
                                              Data64* plaintext,
                                              Modulus64* modulus, int n_power);

    //////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    __global__ void initialize_random_states_kernel(curandState_t* states,
                                                    Data64 seed,
                                                    int total_threads);

    __global__ void encrypt_lwe_kernel(curandState_t* states, int32_t* sk,
                                       int32_t* output_a, int32_t* output_b,
                                       int n, int k, int total_state_count);

} // namespace heongpu

#endif // HEONGPU_ENCRYPTION_H