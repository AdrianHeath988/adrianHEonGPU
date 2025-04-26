// Copyright 2024-2025 Alişah Özcan
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Developer: Alişah Özcan

#ifndef HEONGPU_BFV_OPERATOR_H
#define HEONGPU_BFV_OPERATOR_H

#include "ntt.cuh"
#include "fft.cuh"
#include "addition.cuh"
#include "multiplication.cuh"
#include "switchkey.cuh"
#include "keygeneration.cuh"
#include "bootstrapping.cuh"

#include "bfv/context.cuh"
#include "bfv/encoder.cuh"
#include "bfv/plaintext.cuh"
#include "bfv/ciphertext.cuh"
#include "bfv/evaluationkey.cuh"

namespace heongpu
{

    /**
     * @brief HEOperator is responsible for performing homomorphic operations on
     * encrypted data, such as addition, subtraction, multiplication, and other
     * functions.
     *
     * The HEOperator class is initialized with encryption parameters and
     * provides various functions for performing operations on ciphertexts,
     * including BFV scheme. It supports both in-place and
     * out-of-place operations, as well as asynchronous processing using CUDA
     * streams.
     */
    template <> class HEOperator<Scheme::BFV>
    {
      protected:
        /**
         * @brief Construct a new HEOperator object with the given parameters.
         *
         * @param context Reference to the Parameters object that sets the
         * encryption parameters for the operator.
         */
        __host__ HEOperator(HEContext<Scheme::BFV>& context,
                            HEEncoder<Scheme::BFV>& encoder);

      public:
        /**
         * @brief Adds two ciphertexts and stores the result in the output.
         *
         * @param input1 First input ciphertext to be added.
         * @param input2 Second input ciphertext to be added.
         * @param output Ciphertext where the result of the addition is stored.
         */
        __host__ void add(Ciphertext<Scheme::BFV>& input1,
                          Ciphertext<Scheme::BFV>& input2,
                          Ciphertext<Scheme::BFV>& output,
                          const ExecutionOptions& options = ExecutionOptions());

        /**
         * @brief Adds the second ciphertext to the first ciphertext, modifying
         * the first ciphertext with the result.
         *
         * @param input1 The ciphertext to which the value of input2 will be
         * added.
         * @param input2 The ciphertext to be added to input1.
         */
        __host__ void
        add_inplace(Ciphertext<Scheme::BFV>& input1,
                    Ciphertext<Scheme::BFV>& input2,
                    const ExecutionOptions& options = ExecutionOptions())
        {
            add(input1, input2, input1, options);
        }

        /**
         * @brief Subtracts the second ciphertext from the first and stores the
         * result in the output.
         *
         * @param input1 First input ciphertext (minuend).
         * @param input2 Second input ciphertext (subtrahend).
         * @param output Ciphertext where the result of the subtraction is
         * stored.
         */
        __host__ void sub(Ciphertext<Scheme::BFV>& input1,
                          Ciphertext<Scheme::BFV>& input2,
                          Ciphertext<Scheme::BFV>& output,
                          const ExecutionOptions& options = ExecutionOptions());

        /**
         * @brief Subtracts the second ciphertext from the first, modifying the
         * first ciphertext with the result.
         *
         * @param input1 The ciphertext from which input2 will be subtracted.
         * @param input2 The ciphertext to subtract from input1.
         */
        __host__ void
        sub_inplace(Ciphertext<Scheme::BFV>& input1,
                    Ciphertext<Scheme::BFV>& input2,
                    const ExecutionOptions& options = ExecutionOptions())
        {
            sub(input1, input2, input1, options);
        }

        /**
         * @brief Negates a ciphertext and stores the result in the output.
         *
         * @param input1 Input ciphertext to be negated.
         * @param output Ciphertext where the result of the negation is stored.
         */
        __host__ void
        negate(Ciphertext<Scheme::BFV>& input1, Ciphertext<Scheme::BFV>& output,
               const ExecutionOptions& options = ExecutionOptions());

        /**
         * @brief Negates a ciphertext in-place, modifying the input ciphertext.
         *
         * @param input1 Ciphertext to be negated.
         */
        __host__ void
        negate_inplace(Ciphertext<Scheme::BFV>& input1,
                       const ExecutionOptions& options = ExecutionOptions())
        {
            negate(input1, input1, options);
        }

        /**
         * @brief Adds a ciphertext and a plaintext and stores the result in the
         * output.
         *
         * @param input1 Input ciphertext to be added.
         * @param input2 Input plaintext to be added.
         * @param output Ciphertext where the result of the addition is stored.
         */
        __host__ void
        add_plain(Ciphertext<Scheme::BFV>& input1,
                  Plaintext<Scheme::BFV>& input2,
                  Ciphertext<Scheme::BFV>& output,
                  const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument(
                    "Ciphertext and Plaintext can not be added because "
                    "ciphertext has non-linear partl!");
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    if (input1_.in_ntt_domain_ ||
                                        input2_.in_ntt_domain_)
                                    {
                                        throw std::logic_error(
                                            "BFV ciphertext or "
                                            "plaintext "
                                            "should be not in NTT "
                                            "domain");
                                    }
                                    add_plain_bfv(input1_, input2_, output_,
                                                  options.stream_);

                                    output_.scheme_ = scheme_;
                                    output_.ring_size_ = n;
                                    output_.coeff_modulus_count_ = Q_size_;
                                    output_.cipher_size_ = 2;
                                    output_.in_ntt_domain_ =
                                        input1_.in_ntt_domain_;
                                    output_.relinearization_required_ =
                                        input1_.relinearization_required_;
                                },
                                options);
                        },
                        options, false);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Adds a plaintext to a ciphertext in-place, modifying the input
         * ciphertext.
         *
         * @param input1 Ciphertext to which the plaintext will be added.
         * @param input2 Plaintext to be added to the ciphertext.
         */
        __host__ void
        add_plain_inplace(Ciphertext<Scheme::BFV>& input1,
                          Plaintext<Scheme::BFV>& input2,
                          const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument(
                    "Ciphertext and Plaintext can not be added because "
                    "ciphertext has non-linear partl!");
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            if (input1.in_ntt_domain_ || input2.in_ntt_domain_)
                            {
                                throw std::logic_error(
                                    "BFV ciphertext or plaintext "
                                    "should be not in NTT domain");
                            }
                            add_plain_bfv_inplace(input1_, input2_,
                                                  options.stream_);
                        },
                        options, false);
                },
                options, true);
        }

        /**
         * @brief Subtracts a plaintext from a ciphertext and stores the result
         * in the output.
         *
         * @param input1 Input ciphertext (minuend).
         * @param input2 Input plaintext (subtrahend).
         * @param output Ciphertext where the result of the subtraction is
         * stored.
         */
        __host__ void
        sub_plain(Ciphertext<Scheme::BFV>& input1,
                  Plaintext<Scheme::BFV>& input2,
                  Ciphertext<Scheme::BFV>& output,
                  const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument(
                    "Ciphertext and Plaintext can not be added because "
                    "ciphertext has non-linear partl!");
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    if (input1_.in_ntt_domain_ ||
                                        input2_.in_ntt_domain_)
                                    {
                                        throw std::logic_error(
                                            "BFV ciphertext or "
                                            "plaintext "
                                            "should be not in NTT "
                                            "domain");
                                    }
                                    sub_plain_bfv(input1_, input2_, output_,
                                                  options.stream_);

                                    output_.scheme_ = scheme_;
                                    output_.ring_size_ = n;
                                    output_.coeff_modulus_count_ = Q_size_;
                                    output_.cipher_size_ = 2;
                                    output_.in_ntt_domain_ =
                                        input1_.in_ntt_domain_;
                                    output_.relinearization_required_ =
                                        input1_.relinearization_required_;
                                },
                                options);
                        },
                        options, false);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Subtracts a plaintext from a ciphertext in-place, modifying
         * the input ciphertext.
         *
         * @param input1 Ciphertext from which the plaintext will be subtracted.
         * @param input2 Plaintext to be subtracted from the ciphertext.
         */
        __host__ void
        sub_plain_inplace(Ciphertext<Scheme::BFV>& input1,
                          Plaintext<Scheme::BFV>& input2,
                          const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument(
                    "Ciphertext and Plaintext can not be added because "
                    "ciphertext has non-linear partl!");
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            if (input1.in_ntt_domain_ || input2.in_ntt_domain_)
                            {
                                throw std::logic_error(
                                    "BFV ciphertext or plaintext "
                                    "should be not in NTT domain");
                            }
                            sub_plain_bfv_inplace(input1_, input2_,
                                                  options.stream_);
                        },
                        options, false);
                },
                options, true);
        }

        /**
         * @brief Multiplies two ciphertexts and stores the result in the
         * output.
         *
         * @param input1 First input ciphertext to be multiplied.
         * @param input2 Second input ciphertext to be multiplied.
         * @param output Ciphertext where the result of the multiplication is
         * stored.
         */
        __host__ void
        multiply(Ciphertext<Scheme::BFV>& input1,
                 Ciphertext<Scheme::BFV>& input2,
                 Ciphertext<Scheme::BFV>& output,
                 const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_ ||
                input2.relinearization_required_)
            {
                throw std::invalid_argument(
                    "Ciphertexts can not be multiplied because of the "
                    "non-linear part! Please use relinearization operation!");
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Ciphertext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply_bfv(input1_, input2_, output_,
                                                 options.stream_);

                                    output_.scheme_ = scheme_;
                                    output_.ring_size_ = n;
                                    output_.coeff_modulus_count_ = Q_size_;
                                    output_.cipher_size_ = 3;
                                    output_.in_ntt_domain_ =
                                        input1_.in_ntt_domain_;
                                    output_.relinearization_required_ = true;
                                },
                                options);
                        },
                        options, (&input2 == &output));
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Multiplies two ciphertexts in-place, modifying the first
         * ciphertext.
         *
         * @param input1 Ciphertext to be multiplied, and where the result will
         * be stored.
         * @param input2 Second input ciphertext to be multiplied.
         */
        __host__ void
        multiply_inplace(Ciphertext<Scheme::BFV>& input1,
                         Ciphertext<Scheme::BFV>& input2,
                         const ExecutionOptions& options = ExecutionOptions())
        {
            multiply(input1, input2, input1, options);
        }

        /**
         * @brief Multiplies a ciphertext and a plaintext and stores the result
         * in the output.
         *
         * @param input1 Input ciphertext to be multiplied.
         * @param input2 Input plaintext to be multiplied.
         * @param output Ciphertext where the result of the multiplication is
         * stored.
         */
        __host__ void
        multiply_plain(Ciphertext<Scheme::BFV>& input1,
                       Plaintext<Scheme::BFV>& input2,
                       Ciphertext<Scheme::BFV>& output,
                       const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument(
                    "Ciphertext and Plaintext can not be multiplied because of "
                    "the non-linear part! Please use relinearization "
                    "operation!");
            }

            if (input1.memory_size() < (2 * n * Q_size_))
            {
                throw std::invalid_argument("Invalid Ciphertexts size!");
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    if (input1_.in_ntt_domain_ !=
                                        input2_.in_ntt_domain_)
                                    {
                                        throw std::logic_error(
                                            "BFV ciphertext or "
                                            "plaintext "
                                            "should be not in same "
                                            "domain");
                                    }

                                    if (input2_.size() < n)
                                    {
                                        throw std::invalid_argument(
                                            "Invalid Plaintext size!");
                                    }

                                    multiply_plain_bfv(input1_, input2_,
                                                       output_,
                                                       options.stream_);

                                    output_.scheme_ = scheme_;
                                    output_.ring_size_ = n;
                                    output_.coeff_modulus_count_ = Q_size_;
                                    output_.cipher_size_ = 2;
                                    output_.in_ntt_domain_ =
                                        input1_.in_ntt_domain_;
                                    output_.relinearization_required_ =
                                        input1_.relinearization_required_;
                                },
                                options);
                        },
                        options, false);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Multiplies a plaintext with a ciphertext in-place, modifying
         * the input ciphertext.
         *
         * @param input1 Ciphertext to be multiplied by the plaintext, and where
         * the result will be stored.
         * @param input2 Plaintext to be multiplied with the ciphertext.
         */
        __host__ void multiply_plain_inplace(
            Ciphertext<Scheme::BFV>& input1, Plaintext<Scheme::BFV>& input2,
            const ExecutionOptions& options = ExecutionOptions())
        {
            multiply_plain(input1, input2, input1, options);
        }

        /**
         * @brief Performs in-place relinearization of the given ciphertext
         * using the provided relin key.
         *
         * @param input1 Ciphertext to be relinearized.
         * @param relin_key The Relinkey object used for relinearization.
         */
        __host__ void relinearize_inplace(
            Ciphertext<Scheme::BFV>& input1, Relinkey<Scheme::BFV>& relin_key,
            const ExecutionOptions& options = ExecutionOptions())
        {
            if ((!input1.relinearization_required_))
            {
                throw std::invalid_argument(
                    "Ciphertexts can not use relinearization, since no "
                    "non-linear part!");
            }

            if (input1.memory_size() < (3 * n * Q_size_))
            {
                throw std::invalid_argument("Invalid Ciphertexts size!");
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    switch (static_cast<int>(relin_key.key_type))
                    {
                        case 1: // KEYSWITCHING_METHOD_I

                            if (input1_.in_ntt_domain_ != false)
                            {
                                throw std::invalid_argument(
                                    "Ciphertext should be in intt domain");
                            }

                            relinearize_seal_method_inplace(input1_, relin_key,
                                                            options.stream_);

                            break;
                        case 2: // KEYSWITCHING_METHOD_II

                            if (input1_.in_ntt_domain_ != false)
                            {
                                throw std::invalid_argument(
                                    "Ciphertext should be in intt domain");
                            }

                            relinearize_external_product_method2_inplace(
                                input1_, relin_key, options.stream_);

                            break;
                        case 3: // KEYSWITCHING_METHOD_III

                            if (input1_.in_ntt_domain_ != false)
                            {
                                throw std::invalid_argument(
                                    "Ciphertext should be in intt domain");
                            }

                            relinearize_external_product_method_inplace(
                                input1_, relin_key, options.stream_);

                            break;
                        default:
                            throw std::invalid_argument(
                                "Invalid Key Switching Type");
                            break;
                    }

                    input1_.relinearization_required_ = false;
                },
                options, true);
        }

        /**
         * @brief Rotates the rows of a ciphertext by a given shift value and
         * stores the result in the output.
         *
         * @param input1 Input ciphertext to be rotated.
         * @param output Ciphertext where the result of the rotation is stored.
         * @param galois_key Galois key used for the rotation operation.
         * @param shift Number of positions to shift the rows.
         */
        __host__ void
        rotate_rows(Ciphertext<Scheme::BFV>& input1,
                    Ciphertext<Scheme::BFV>& output,
                    Galoiskey<Scheme::BFV>& galois_key, int shift,
                    const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument("Ciphertext can not be rotated!");
            }

            if (input1.memory_size() < (2 * n * Q_size_))
            {
                throw std::invalid_argument("Invalid Ciphertexts size!");
            }

            if (shift == 0)
            {
                output = input1;
                return;
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    output_storage_manager(
                        output,
                        [&](Ciphertext<Scheme::BFV>& output_)
                        {
                            switch (static_cast<int>(galois_key.key_type))
                            {
                                case 1: // KEYSWITCHING_METHOD_I

                                    if (input1_.in_ntt_domain_ != false)
                                    {
                                        throw std::invalid_argument(
                                            "Ciphertext should be in intt "
                                            "domain");
                                    }

                                    rotate_method_I(input1_, output_,
                                                    galois_key, shift,
                                                    options.stream_);

                                    break;
                                case 2: // KEYSWITCHING_METHOD_II

                                    if (input1_.in_ntt_domain_ != false)
                                    {
                                        throw std::invalid_argument(
                                            "Ciphertext should be in intt "
                                            "domain");
                                    }

                                    rotate_method_II(input1_, output_,
                                                     galois_key, shift,
                                                     options.stream_);

                                    break;
                                case 3: // KEYSWITCHING_METHOD_III

                                    throw std::invalid_argument(
                                        "KEYSWITCHING_METHOD_III are not "
                                        "supported because of "
                                        "high memory consumption for rotation "
                                        "operation!");

                                    break;
                                default:
                                    throw std::invalid_argument(
                                        "Invalid Key Switching Type");
                                    break;
                            }

                            output_.scheme_ = scheme_;
                            output_.ring_size_ = n;
                            output_.coeff_modulus_count_ = Q_size_;
                            output_.cipher_size_ = 2;
                            output_.in_ntt_domain_ = input1_.in_ntt_domain_;
                            output_.relinearization_required_ =
                                input1_.relinearization_required_;
                        },
                        options);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Rotates the rows of a ciphertext in-place by a given shift
         * value, modifying the input ciphertext.
         *
         * @param input1 Ciphertext to be rotated.
         * @param galois_key Galois key used for the rotation operation.
         * @param shift Number of positions to shift the rows.
         */
        __host__ void rotate_rows_inplace(
            Ciphertext<Scheme::BFV>& input1, Galoiskey<Scheme::BFV>& galois_key,
            int shift, const ExecutionOptions& options = ExecutionOptions())
        {
            if (shift == 0)
            {
                return;
            }

            rotate_rows(input1, input1, galois_key, shift, options);
        }

        /**
         * @brief Rotates the columns of a ciphertext and stores the result in
         * the output.
         *
         * @param input1 Input ciphertext to be rotated.
         * @param output Ciphertext where the result of the rotation is stored.
         * @param galois_key Galois key used for the rotation operation.
         */
        __host__ void
        rotate_columns(Ciphertext<Scheme::BFV>& input1,
                       Ciphertext<Scheme::BFV>& output,
                       Galoiskey<Scheme::BFV>& galois_key,
                       const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument("Ciphertext can not be rotated!");
            }

            if (input1.memory_size() < (2 * n * Q_size_))
            {
                throw std::invalid_argument("Invalid Ciphertexts size!");
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    output_storage_manager(
                        output,
                        [&](Ciphertext<Scheme::BFV>& output_)
                        {
                            switch (static_cast<int>(galois_key.key_type))
                            {
                                case 1: // KEYSWITCHING_METHOD_I

                                    if (input1_.in_ntt_domain_ != false)
                                    {
                                        throw std::invalid_argument(
                                            "Ciphertext should be in intt "
                                            "domain");
                                    }

                                    rotate_columns_method_I(input1_, output_,
                                                            galois_key,
                                                            options.stream_);

                                    break;
                                case 2: // KEYSWITCHING_METHOD_II

                                    rotate_columns_method_II(input1_, output_,
                                                             galois_key,
                                                             options.stream_);

                                    break;
                                case 3: // KEYSWITCHING_METHOD_III

                                    throw std::invalid_argument(
                                        "KEYSWITCHING_METHOD_III are not "
                                        "supported because of "
                                        "high memory consumption for rotation "
                                        "operation!");

                                    break;
                                default:
                                    throw std::invalid_argument(
                                        "Invalid Key Switching Type");
                                    break;
                            }

                            output_.scheme_ = scheme_;
                            output_.ring_size_ = n;
                            output_.coeff_modulus_count_ = Q_size_;
                            output_.cipher_size_ = 2;
                            output_.in_ntt_domain_ = input1_.in_ntt_domain_;
                            output_.relinearization_required_ =
                                input1_.relinearization_required_;
                        },
                        options);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Applies a Galois automorphism to the ciphertext and stores the
         * result in the output.
         *
         * @param input1 Input ciphertext to which the Galois operation will be
         * applied.
         * @param output Ciphertext where the result of the Galois operation is
         * stored.
         * @param galois_key Galois key used for the operation.
         * @param galois_elt The Galois element to apply.
         */
        __host__ void
        apply_galois(Ciphertext<Scheme::BFV>& input1,
                     Ciphertext<Scheme::BFV>& output,
                     Galoiskey<Scheme::BFV>& galois_key, int galois_elt,
                     const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument("Ciphertext can not be rotated!");
            }

            if (input1.memory_size() < (2 * n * Q_size_))
            {
                throw std::invalid_argument("Invalid Ciphertexts size!");
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    output_storage_manager(
                        output,
                        [&](Ciphertext<Scheme::BFV>& output_)
                        {
                            switch (static_cast<int>(galois_key.key_type))
                            {
                                case 1: // KEYSWITCHING_METHOD_I

                                    if (input1_.in_ntt_domain_ != false)
                                    {
                                        throw std::invalid_argument(
                                            "Ciphertext should be in intt "
                                            "domain");
                                    }

                                    apply_galois_method_I(
                                        input1_, output_, galois_key,
                                        galois_elt, options.stream_);

                                    break;
                                case 2: // KEYSWITCHING_METHOD_II

                                    if (input1_.in_ntt_domain_ != false)
                                    {
                                        throw std::invalid_argument(
                                            "Ciphertext should be in intt "
                                            "domain");
                                    }

                                    apply_galois_method_II(
                                        input1_, output_, galois_key,
                                        galois_elt, options.stream_);

                                    break;
                                case 3: // KEYSWITCHING_METHOD_III

                                    throw std::invalid_argument(
                                        "KEYSWITCHING_METHOD_III are not "
                                        "supported because of "
                                        "high memory consumption for rotation "
                                        "operation!");

                                    break;
                                default:
                                    throw std::invalid_argument(
                                        "Invalid Key Switching Type");
                                    break;
                            }

                            output_.scheme_ = scheme_;
                            output_.ring_size_ = n;
                            output_.coeff_modulus_count_ = Q_size_;
                            output_.cipher_size_ = 2;
                            output_.in_ntt_domain_ = input1_.in_ntt_domain_;
                            output_.relinearization_required_ =
                                input1_.relinearization_required_;
                        },
                        options);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Applies a Galois automorphism to the ciphertext in-place,
         * modifying the input ciphertext.
         *
         * @param input1 Ciphertext to which the Galois operation will be
         * applied.
         * @param galois_key Galois key used for the operation.
         * @param galois_elt The Galois element to apply.
         */
        __host__ void apply_galois_inplace(
            Ciphertext<Scheme::BFV>& input1, Galoiskey<Scheme::BFV>& galois_key,
            int galois_elt,
            const ExecutionOptions& options = ExecutionOptions())
        {
            apply_galois(input1, input1, galois_key, galois_elt, options);
        }

        /**
         * @brief Performs key switching on the ciphertext and stores the result
         * in the output.
         *
         * @param input1 Input ciphertext to be key-switched.
         * @param output Ciphertext where the result of the key switching is
         * stored.
         * @param switch_key Switch key used for the key switching operation.
         */
        __host__ void
        keyswitch(Ciphertext<Scheme::BFV>& input1,
                  Ciphertext<Scheme::BFV>& output,
                  Switchkey<Scheme::BFV>& switch_key,
                  const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument("Ciphertext can not be rotated!");
            }

            if (input1.memory_size() < (2 * n * Q_size_))
            {
                throw std::invalid_argument("Invalid Ciphertexts size!");
            }

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    output_storage_manager(
                        output,
                        [&](Ciphertext<Scheme::BFV>& output_)
                        {
                            switch (static_cast<int>(switch_key.key_type))
                            {
                                case 1: // KEYSWITCHING_METHOD_I

                                    if (input1_.in_ntt_domain_ != false)
                                    {
                                        throw std::invalid_argument(
                                            "Ciphertext should be in intt "
                                            "domain");
                                    }

                                    switchkey_method_I(input1_, output_,
                                                       switch_key,
                                                       options.stream_);

                                    break;
                                case 2: // KEYSWITCHING_METHOD_II

                                    if (input1_.in_ntt_domain_ != false)
                                    {
                                        throw std::invalid_argument(
                                            "Ciphertext should be in intt "
                                            "domain");
                                    }

                                    switchkey_method_II(input1_, output_,
                                                        switch_key,
                                                        options.stream_);

                                    break;
                                case 3: // KEYSWITCHING_METHOD_III

                                    throw std::invalid_argument(
                                        "KEYSWITCHING_METHOD_III are not "
                                        "supported because of "
                                        "high memory consumption for keyswitch "
                                        "operation!");

                                    break;
                                default:
                                    throw std::invalid_argument(
                                        "Invalid Key Switching Type");
                                    break;
                            }

                            output_.scheme_ = scheme_;
                            output_.ring_size_ = n;
                            output_.coeff_modulus_count_ = Q_size_;
                            output_.cipher_size_ = 2;
                            output_.in_ntt_domain_ = input1_.in_ntt_domain_;
                            output_.relinearization_required_ =
                                input1_.relinearization_required_;
                        },
                        options);
                },
                options, (&input1 == &output));
        }

        __host__ void multiply_power_of_X(
            Ciphertext<Scheme::BFV>& input1, Ciphertext<Scheme::BFV>& output,
            int index, const ExecutionOptions& options = ExecutionOptions())
        {
            if (index != 0)
            {
                if (input1.in_ntt_domain_ != false)
                {
                    throw std::invalid_argument(
                        "Ciphertext should be in intt domain");
                }

                if (input1.memory_size() < (2 * n * Q_size_))
                {
                    throw std::invalid_argument("Invalid Ciphertexts size!");
                }

                input_storage_manager(
                    input1,
                    [&](Ciphertext<Scheme::BFV>& input1_)
                    {
                        output_storage_manager(
                            output,
                            [&](Ciphertext<Scheme::BFV>& output_)
                            {
                                negacyclic_shift_poly_coeffmod(
                                    input1_, output_, index, options.stream_);

                                output.scheme_ = scheme_;
                                output.ring_size_ = n;
                                output.coeff_modulus_count_ = Q_size_;
                                output.cipher_size_ = 2;
                                output.in_ntt_domain_ = input1.in_ntt_domain_;
                                output.relinearization_required_ =
                                    input1.relinearization_required_;
                            },
                            options);
                    },
                    options, (&input1 == &output));
            }
        }

        /**
         * @brief Transforms a plaintext to the NTT domain and stores the result
         * in the output.
         *
         * @param input1 Input plaintext to be transformed.
         * @param output Plaintext where the result of the transformation is
         * stored.
         */
        __host__ void
        transform_to_ntt(Plaintext<Scheme::BFV>& input1,
                         Plaintext<Scheme::BFV>& output,
                         const ExecutionOptions& options = ExecutionOptions())
        {
            if (!input1.in_ntt_domain_)
            {
                if (input1.size() < n)
                {
                    throw std::invalid_argument("Invalid Ciphertexts size!");
                }

                input_storage_manager(
                    input1,
                    [&](Plaintext<Scheme::BFV>& input1_)
                    {
                        output_storage_manager(
                            output,
                            [&](Plaintext<Scheme::BFV>& output_)
                            {
                                transform_to_ntt_bfv_plain(input1, output,
                                                           options.stream_);

                                output.scheme_ = input1.scheme_;
                                output.plain_size_ = (n * Q_size_);
                                output.in_ntt_domain_ = true;
                            },
                            options);
                    },
                    options, (&input1 == &output));
            }
        }

        /**
         * @brief Transforms a plaintext to the NTT domain in-place, modifying
         * the input plaintext.
         *
         * @param input1 Plaintext to be transformed.
         */
        __host__ void transform_to_ntt_inplace(
            Plaintext<Scheme::BFV>& input1,
            const ExecutionOptions& options = ExecutionOptions())
        {
            transform_to_ntt(input1, input1, options);
        }

        /**
         * @brief Transforms a ciphertext to the NTT domain and stores the
         * result in the output.
         *
         * @param input1 Input ciphertext to be transformed.
         * @param output Ciphertext where the result of the transformation is
         * stored.
         */
        __host__ void
        transform_to_ntt(Ciphertext<Scheme::BFV>& input1,
                         Ciphertext<Scheme::BFV>& output,
                         const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument(
                    "Ciphertexts can not be transformed to NTT!");
            }

            if (!input1.in_ntt_domain_)
            {
                if (input1.memory_size() < (2 * n * Q_size_))
                {
                    throw std::invalid_argument("Invalid Ciphertexts size!");
                }

                input_storage_manager(
                    input1,
                    [&](Ciphertext<Scheme::BFV>& input1_)
                    {
                        output_storage_manager(
                            output,
                            [&](Ciphertext<Scheme::BFV>& output_)
                            {
                                transform_to_ntt_bfv_cipher(input1_, output_,
                                                            options.stream_);

                                output.scheme_ = scheme_;
                                output.ring_size_ = n;
                                output.coeff_modulus_count_ = Q_size_;
                                output.cipher_size_ = 2;
                                output.in_ntt_domain_ = true;
                                output.relinearization_required_ =
                                    input1.relinearization_required_;
                            },
                            options);
                    },
                    options, (&input1 == &output));
            }
        }

        /**
         * @brief Transforms a ciphertext to the NTT domain in-place, modifying
         * the input ciphertext.
         *
         * @param input1 Ciphertext to be transformed.
         */
        __host__ void transform_to_ntt_inplace(
            Ciphertext<Scheme::BFV>& input1,
            const ExecutionOptions& options = ExecutionOptions())
        {
            transform_to_ntt(input1, input1, options);
        }

        /**
         * @brief Transforms a ciphertext from the NTT domain and stores the
         * result in the output.
         *
         * @param input1 Input ciphertext to be transformed from the NTT domain.
         * @param output Ciphertext where the result of the transformation is
         * stored.
         */
        __host__ void
        transform_from_ntt(Ciphertext<Scheme::BFV>& input1,
                           Ciphertext<Scheme::BFV>& output,
                           const ExecutionOptions& options = ExecutionOptions())
        {
            if (input1.relinearization_required_)
            {
                throw std::invalid_argument(
                    "Ciphertexts can not be transformed from NTT!");
            }

            if (input1.in_ntt_domain_)
            {
                if (input1.memory_size() < (2 * n * Q_size_))
                {
                    throw std::invalid_argument("Invalid Ciphertexts size!");
                }

                input_storage_manager(
                    input1,
                    [&](Ciphertext<Scheme::BFV>& input1_)
                    {
                        output_storage_manager(
                            output,
                            [&](Ciphertext<Scheme::BFV>& output_)
                            {
                                transform_from_ntt_bfv_cipher(input1_, output_,
                                                              options.stream_);

                                output.scheme_ = scheme_;
                                output.ring_size_ = n;
                                output.coeff_modulus_count_ = Q_size_;
                                output.cipher_size_ = 2;
                                output.in_ntt_domain_ = false;
                                output.relinearization_required_ =
                                    input1.relinearization_required_;
                            },
                            options);
                    },
                    options, (&input1 == &output));
            }
        }

        /**
         * @brief Transforms a ciphertext from the NTT domain in-place,
         * modifying the input ciphertext.
         *
         * @param input1 Ciphertext to be transformed from the NTT domain.
         */
        __host__ void transform_from_ntt_inplace(
            Ciphertext<Scheme::BFV>& input1,
            const ExecutionOptions& options = ExecutionOptions())
        {
            transform_from_ntt(input1, input1, options);
        }

        HEOperator() = default;
        HEOperator(const HEOperator& copy) = default;
        HEOperator(HEOperator&& source) = default;
        HEOperator& operator=(const HEOperator& assign) = default;
        HEOperator& operator=(HEOperator&& assign) = default;

        // private:
      protected:
        __host__ void add_plain_bfv(Ciphertext<Scheme::BFV>& input1,
                                    Plaintext<Scheme::BFV>& input2,
                                    Ciphertext<Scheme::BFV>& output,
                                    const cudaStream_t stream);

        __host__ void add_plain_bfv_inplace(Ciphertext<Scheme::BFV>& input1,
                                            Plaintext<Scheme::BFV>& input2,
                                            const cudaStream_t stream);

        __host__ void sub_plain_bfv(Ciphertext<Scheme::BFV>& input1,
                                    Plaintext<Scheme::BFV>& input2,
                                    Ciphertext<Scheme::BFV>& output,
                                    const cudaStream_t stream);

        __host__ void sub_plain_bfv_inplace(Ciphertext<Scheme::BFV>& input1,
                                            Plaintext<Scheme::BFV>& input2,
                                            const cudaStream_t stream);

        __host__ void multiply_bfv(Ciphertext<Scheme::BFV>& input1,
                                   Ciphertext<Scheme::BFV>& input2,
                                   Ciphertext<Scheme::BFV>& output,
                                   const cudaStream_t stream);

        __host__ void multiply_plain_bfv(Ciphertext<Scheme::BFV>& input1,
                                         Plaintext<Scheme::BFV>& input2,
                                         Ciphertext<Scheme::BFV>& output,
                                         const cudaStream_t stream);

        ///////////////////////////////////////////////////

        __host__ void
        relinearize_seal_method_inplace(Ciphertext<Scheme::BFV>& input1,
                                        Relinkey<Scheme::BFV>& relin_key,
                                        const cudaStream_t stream);

        __host__ void relinearize_external_product_method_inplace(
            Ciphertext<Scheme::BFV>& input1, Relinkey<Scheme::BFV>& relin_key,
            const cudaStream_t stream);

        __host__ void relinearize_external_product_method2_inplace(
            Ciphertext<Scheme::BFV>& input1, Relinkey<Scheme::BFV>& relin_key,
            const cudaStream_t stream);

        ///////////////////////////////////////////////////

        __host__ void rotate_method_I(Ciphertext<Scheme::BFV>& input1,
                                      Ciphertext<Scheme::BFV>& output,
                                      Galoiskey<Scheme::BFV>& galois_key,
                                      int shift, const cudaStream_t stream);

        __host__ void rotate_method_II(Ciphertext<Scheme::BFV>& input1,
                                       Ciphertext<Scheme::BFV>& output,
                                       Galoiskey<Scheme::BFV>& galois_key,
                                       int shift, const cudaStream_t stream);

        ///////////////////////////////////////////////////

        // TODO: Merge with rotation, provide code integrity
        __host__ void apply_galois_method_I(Ciphertext<Scheme::BFV>& input1,
                                            Ciphertext<Scheme::BFV>& output,
                                            Galoiskey<Scheme::BFV>& galois_key,
                                            int galois_elt,
                                            const cudaStream_t stream);

        __host__ void apply_galois_method_II(Ciphertext<Scheme::BFV>& input1,
                                             Ciphertext<Scheme::BFV>& output,
                                             Galoiskey<Scheme::BFV>& galois_key,
                                             int galois_elt,
                                             const cudaStream_t stream);

        ///////////////////////////////////////////////////

        __host__ void rotate_columns_method_I(
            Ciphertext<Scheme::BFV>& input1, Ciphertext<Scheme::BFV>& output,
            Galoiskey<Scheme::BFV>& galois_key, const cudaStream_t stream);

        __host__ void rotate_columns_method_II(
            Ciphertext<Scheme::BFV>& input1, Ciphertext<Scheme::BFV>& output,
            Galoiskey<Scheme::BFV>& galois_key, const cudaStream_t stream);

        ///////////////////////////////////////////////////

        __host__ void switchkey_method_I(Ciphertext<Scheme::BFV>& input1,
                                         Ciphertext<Scheme::BFV>& output,
                                         Switchkey<Scheme::BFV>& switch_key,
                                         const cudaStream_t stream);

        __host__ void switchkey_method_II(Ciphertext<Scheme::BFV>& input1,
                                          Ciphertext<Scheme::BFV>& output,
                                          Switchkey<Scheme::BFV>& switch_key,
                                          const cudaStream_t stream);

        ///////////////////////////////////////////////////

        __host__ void
        negacyclic_shift_poly_coeffmod(Ciphertext<Scheme::BFV>& input1,
                                       Ciphertext<Scheme::BFV>& output,
                                       int index, const cudaStream_t stream);

        ///////////////////////////////////////////////////

        __host__ void transform_to_ntt_bfv_plain(Plaintext<Scheme::BFV>& input1,
                                                 Plaintext<Scheme::BFV>& output,
                                                 const cudaStream_t stream);

        __host__ void
        transform_to_ntt_bfv_cipher(Ciphertext<Scheme::BFV>& input1,
                                    Ciphertext<Scheme::BFV>& output,
                                    const cudaStream_t stream);

        __host__ void
        transform_from_ntt_bfv_cipher(Ciphertext<Scheme::BFV>& input1,
                                      Ciphertext<Scheme::BFV>& output,
                                      const cudaStream_t stream);

        // private:
      protected:
        scheme_type scheme_;

        int n;

        int n_power;

        int bsk_mod_count_;

        // New
        int Q_prime_size_;
        int Q_size_;
        int P_size_;

        std::shared_ptr<DeviceVector<Modulus64>> modulus_;
        std::shared_ptr<DeviceVector<Root64>> ntt_table_;
        std::shared_ptr<DeviceVector<Root64>> intt_table_;
        std::shared_ptr<DeviceVector<Ninverse64>> n_inverse_;
        std::shared_ptr<DeviceVector<Data64>> last_q_modinv_;

        std::shared_ptr<DeviceVector<Modulus64>> base_Bsk_;
        std::shared_ptr<DeviceVector<Root64>> bsk_ntt_tables_; // check
        std::shared_ptr<DeviceVector<Root64>> bsk_intt_tables_; // check
        std::shared_ptr<DeviceVector<Ninverse64>> bsk_n_inverse_; // check

        Modulus64 m_tilde_;
        std::shared_ptr<DeviceVector<Data64>> base_change_matrix_Bsk_;
        std::shared_ptr<DeviceVector<Data64>>
            inv_punctured_prod_mod_base_array_;
        std::shared_ptr<DeviceVector<Data64>> base_change_matrix_m_tilde_;

        Data64 inv_prod_q_mod_m_tilde_;
        std::shared_ptr<DeviceVector<Data64>> inv_m_tilde_mod_Bsk_;
        std::shared_ptr<DeviceVector<Data64>> prod_q_mod_Bsk_;
        std::shared_ptr<DeviceVector<Data64>> inv_prod_q_mod_Bsk_;

        Modulus64 plain_modulus_;

        std::shared_ptr<DeviceVector<Data64>> base_change_matrix_q_;
        std::shared_ptr<DeviceVector<Data64>> base_change_matrix_msk_;

        std::shared_ptr<DeviceVector<Data64>> inv_punctured_prod_mod_B_array_;
        Data64 inv_prod_B_mod_m_sk_;
        std::shared_ptr<DeviceVector<Data64>> prod_B_mod_q_;

        std::shared_ptr<DeviceVector<Modulus64>> q_Bsk_merge_modulus_;
        std::shared_ptr<DeviceVector<Root64>> q_Bsk_merge_ntt_tables_;
        std::shared_ptr<DeviceVector<Root64>> q_Bsk_merge_intt_tables_;
        std::shared_ptr<DeviceVector<Ninverse64>> q_Bsk_n_inverse_;

        std::shared_ptr<DeviceVector<Data64>> half_p_;
        std::shared_ptr<DeviceVector<Data64>> half_mod_;

        Data64 upper_threshold_;
        std::shared_ptr<DeviceVector<Data64>> upper_halfincrement_;

        Data64 Q_mod_t_;
        std::shared_ptr<DeviceVector<Data64>> coeeff_div_plainmod_;

        /////////

        int d;
        int d_tilda;
        int r_prime;

        std::shared_ptr<DeviceVector<Modulus64>> B_prime_;
        std::shared_ptr<DeviceVector<Root64>> B_prime_ntt_tables_;
        std::shared_ptr<DeviceVector<Root64>> B_prime_intt_tables_;
        std::shared_ptr<DeviceVector<Ninverse64>> B_prime_n_inverse_;

        std::shared_ptr<DeviceVector<Data64>> base_change_matrix_D_to_B_;
        std::shared_ptr<DeviceVector<Data64>> base_change_matrix_B_to_D_;
        std::shared_ptr<DeviceVector<Data64>> Mi_inv_D_to_B_;
        std::shared_ptr<DeviceVector<Data64>> Mi_inv_B_to_D_;
        std::shared_ptr<DeviceVector<Data64>> prod_D_to_B_;
        std::shared_ptr<DeviceVector<Data64>> prod_B_to_D_;

        // Method2
        std::shared_ptr<DeviceVector<Data64>> base_change_matrix_D_to_Q_tilda_;
        std::shared_ptr<DeviceVector<Data64>> Mi_inv_D_to_Q_tilda_;
        std::shared_ptr<DeviceVector<Data64>> prod_D_to_Q_tilda_;

        std::shared_ptr<DeviceVector<int>> I_j_;
        std::shared_ptr<DeviceVector<int>> I_location_;
        std::shared_ptr<DeviceVector<int>> Sk_pair_;

        /////////

        std::vector<Modulus64> prime_vector_; // in CPU

        // Temp(to avoid allocation time)

        // new method
        DeviceVector<int> new_prime_locations_;
        DeviceVector<int> new_input_locations_;
        int* new_prime_locations;
        int* new_input_locations;

        // Encode params
        int slot_count_;
        std::shared_ptr<DeviceVector<Modulus64>>
            plain_modulus_pointer_; // we already have it
        std::shared_ptr<DeviceVector<Ninverse64>> n_plain_inverse_;
        std::shared_ptr<DeviceVector<Root64>> plain_intt_tables_;
        std::shared_ptr<DeviceVector<Data64>> encoding_location_;

      protected:
        // Just for copy parameters, not memory!
        __host__ Ciphertext<Scheme::BFV>
        operator_from_ciphertext(Ciphertext<Scheme::BFV>& input,
                                 cudaStream_t stream = cudaStreamDefault);
    };

    /**
     * @brief HEArithmeticOperator performs arithmetic operations on
     * ciphertexts.
     */
    template <>
    class HEArithmeticOperator<Scheme::BFV> : public HEOperator<Scheme::BFV>
    {
      public:
        /**
         * @brief Constructs a new HEArithmeticOperator object.
         *
         * @param context Encryption parameters.
         * @param encoder Encoder for arithmetic operations.
         */
        HEArithmeticOperator(HEContext<Scheme::BFV>& context,
                             HEEncoder<Scheme::BFV>& encoder);
    };

    /**
     * @brief HELogicOperator performs homomorphic logical operations on
     * ciphertexts.
     */
    template <>
    class HELogicOperator<Scheme::BFV> : private HEOperator<Scheme::BFV>
    {
      public:
        /**
         * @brief Constructs a new HELogicOperator object.
         *
         * @param context Encryption parameters.
         * @param encoder Encoder for homomorphic operations.
         */
        HELogicOperator(HEContext<Scheme::BFV>& context,
                        HEEncoder<Scheme::BFV>& encoder);

        /**
         * @brief Performs logical NOT on ciphertext.
         *
         * @param input1 First input ciphertext.
         * @param output Output ciphertext.
         * @param options Execution options.
         */
        __host__ void NOT(Ciphertext<Scheme::BFV>& input1,
                          Ciphertext<Scheme::BFV>& output,
                          const ExecutionOptions& options = ExecutionOptions())
        {
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    output_storage_manager(
                        output,
                        [&](Ciphertext<Scheme::BFV>& output_)
                        { one_minus_cipher(input1_, output_, options_inner); },
                        options);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical NOT on ciphertext.
         *
         * @param input1 Ciphertext updated with result.
         * @param options Execution options.
         */
        __host__ void
        NOT_inplace(Ciphertext<Scheme::BFV>& input1,
                    const ExecutionOptions& options = ExecutionOptions())
        {
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                { one_minus_cipher_inplace(input1_, options_inner); },
                options, true);
        }

        /**
         * @brief Performs logical AND on two ciphertexts.
         *
         * @param input1 First input ciphertext.
         * @param input2 Second input ciphertext.
         * @param output Output ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void AND(Ciphertext<Scheme::BFV>& input1,
                          Ciphertext<Scheme::BFV>& input2,
                          Ciphertext<Scheme::BFV>& output,
                          Relinkey<Scheme::BFV>& relin_key,
                          const ExecutionOptions& options = ExecutionOptions())
        {
            // TODO: Make it efficient
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Ciphertext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply(input1_, input2_, output_,
                                             options_inner);
                                    relinearize_inplace(output_, relin_key,
                                                        options_inner);
                                },
                                options);
                        },
                        options, (&input2 == &output));
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical AND on two ciphertexts.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Second input ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void
        AND_inplace(Ciphertext<Scheme::BFV>& input1,
                    Ciphertext<Scheme::BFV>& input2,
                    Relinkey<Scheme::BFV>& relin_key,
                    const ExecutionOptions& options = ExecutionOptions())
        {
            AND(input1, input2, input1, relin_key, options);
        }

        /**
         * @brief Performs logical AND on a ciphertext and a plaintext.
         *
         * @param input1 Input ciphertext.
         * @param input2 Input plaintext.
         * @param output Output ciphertext.
         * @param options Execution options.
         */
        __host__ void AND(Ciphertext<Scheme::BFV>& input1,
                          Plaintext<Scheme::BFV>& input2,
                          Ciphertext<Scheme::BFV>& output,
                          const ExecutionOptions& options = ExecutionOptions())
        {
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_) {
                                    multiply_plain(input1_, input2_, output_,
                                                   options_inner);
                                },
                                options);
                        },
                        options, false);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical AND on a ciphertext and a plaintext.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Input plaintext.
         * @param options Execution options.
         */
        __host__ void
        AND_inplace(Ciphertext<Scheme::BFV>& input1,
                    Plaintext<Scheme::BFV>& input2,
                    const ExecutionOptions& options = ExecutionOptions())
        {
            AND(input1, input2, input1, options);
        }

        /**
         * @brief Performs logical OR on two ciphertexts.
         *
         * @param input1 First input ciphertext.
         * @param input2 Second input ciphertext.
         * @param output Output ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void OR(Ciphertext<Scheme::BFV>& input1,
                         Ciphertext<Scheme::BFV>& input2,
                         Ciphertext<Scheme::BFV>& output,
                         Relinkey<Scheme::BFV>& relin_key,
                         const ExecutionOptions& options = ExecutionOptions())
        {
            // TODO: Make it efficient
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            Ciphertext<Scheme::BFV> inner_input1 =
                operator_from_ciphertext(input1, options.stream_);
            Ciphertext<Scheme::BFV> inner_input2 =
                operator_from_ciphertext(input1, options.stream_);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Ciphertext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply(input1_, input2_, inner_input1,
                                             options_inner);
                                    relinearize_inplace(inner_input1, relin_key,
                                                        options_inner);

                                    add(input1_, input2_, inner_input2,
                                        options_inner);

                                    sub(inner_input2, inner_input1, output_,
                                        options_inner);
                                },
                                options);
                        },
                        options, (&input2 == &output));
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical OR on two ciphertexts.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Second input ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void
        OR_inplace(Ciphertext<Scheme::BFV>& input1,
                   Ciphertext<Scheme::BFV>& input2,
                   Relinkey<Scheme::BFV>& relin_key,
                   const ExecutionOptions& options = ExecutionOptions())
        {
            OR(input1, input2, input1, relin_key, options);
        }

        /**
         * @brief Performs logical OR on a ciphertext and a plaintext.
         *
         * @param input1 Input ciphertext.
         * @param input2 Input plaintext.
         * @param output Output ciphertext.
         * @param options Execution options.
         */
        __host__ void OR(Ciphertext<Scheme::BFV>& input1,
                         Plaintext<Scheme::BFV>& input2,
                         Ciphertext<Scheme::BFV>& output,
                         const ExecutionOptions& options = ExecutionOptions())
        {
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            Ciphertext<Scheme::BFV> inner_input1 =
                operator_from_ciphertext(input1, options.stream_);
            Ciphertext<Scheme::BFV> inner_input2 =
                operator_from_ciphertext(input1, options.stream_);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply_plain(input1_, input2_,
                                                   inner_input1, options_inner);

                                    add_plain(input1_, input2_, inner_input2,
                                              options_inner);

                                    sub(inner_input2, inner_input1, output_,
                                        options_inner);
                                },
                                options);
                        },
                        options, false);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical OR on a ciphertext and a plaintext.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Input plaintext.
         * @param options Execution options.
         */
        __host__ void
        OR_inplace(Ciphertext<Scheme::BFV>& input1,
                   Plaintext<Scheme::BFV>& input2,
                   const ExecutionOptions& options = ExecutionOptions())
        {
            OR(input1, input2, input1, options);
        }

        /**
         * @brief Performs logical XOR on two ciphertexts.
         *
         * @param input1 First input ciphertext.
         * @param input2 Second input ciphertext.
         * @param output Output ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void XOR(Ciphertext<Scheme::BFV>& input1,
                          Ciphertext<Scheme::BFV>& input2,
                          Ciphertext<Scheme::BFV>& output,
                          Relinkey<Scheme::BFV>& relin_key,
                          const ExecutionOptions& options = ExecutionOptions())
        {
            // TODO: Make it efficient
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            Ciphertext<Scheme::BFV> inner_input1 =
                operator_from_ciphertext(input1, options.stream_);
            Ciphertext<Scheme::BFV> inner_input2 =
                operator_from_ciphertext(input1, options.stream_);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Ciphertext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply(input1_, input2_, inner_input1,
                                             options_inner);
                                    relinearize_inplace(inner_input1, relin_key,
                                                        options_inner);
                                    add(inner_input1, inner_input1,
                                        inner_input1, options_inner);

                                    add(input1_, input2_, inner_input2,
                                        options_inner);

                                    sub(inner_input2, inner_input1, output_,
                                        options_inner);
                                },
                                options);
                        },
                        options, (&input2 == &output));
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical XOR on two ciphertexts.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Second input ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void
        XOR_inplace(Ciphertext<Scheme::BFV>& input1,
                    Ciphertext<Scheme::BFV>& input2,
                    Relinkey<Scheme::BFV>& relin_key,
                    const ExecutionOptions& options = ExecutionOptions())
        {
            XOR(input1, input2, input1, relin_key, options);
        }

        /**
         * @brief Performs logical XOR on a ciphertext and a plaintext.
         *
         * @param input1 Input ciphertext.
         * @param input2 Input plaintext.
         * @param output Output ciphertext.
         * @param options Execution options.
         */
        __host__ void XOR(Ciphertext<Scheme::BFV>& input1,
                          Plaintext<Scheme::BFV>& input2,
                          Ciphertext<Scheme::BFV>& output,
                          const ExecutionOptions& options = ExecutionOptions())
        {
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            Ciphertext<Scheme::BFV> inner_input1 =
                operator_from_ciphertext(input1, options.stream_);
            Ciphertext<Scheme::BFV> inner_input2 =
                operator_from_ciphertext(input1, options.stream_);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply_plain(input1_, input2_,
                                                   inner_input1, options_inner);
                                    add(inner_input1, inner_input1,
                                        inner_input1, options_inner);

                                    add_plain(input1_, input2_, inner_input2,
                                              options_inner);

                                    sub(inner_input2, inner_input1, output_,
                                        options_inner);
                                },
                                options);
                        },
                        options, false);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical XOR on a ciphertext and a plaintext.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Input plaintext.
         * @param options Execution options.
         */
        __host__ void
        XOR_inplace(Ciphertext<Scheme::BFV>& input1,
                    Plaintext<Scheme::BFV>& input2,
                    const ExecutionOptions& options = ExecutionOptions())
        {
            XOR(input1, input2, input1, options);
        }

        /**
         * @brief Performs logical NAND on two ciphertexts.
         *
         * @param input1 First input ciphertext.
         * @param input2 Second input ciphertext.
         * @param output Output ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void NAND(Ciphertext<Scheme::BFV>& input1,
                           Ciphertext<Scheme::BFV>& input2,
                           Ciphertext<Scheme::BFV>& output,
                           Relinkey<Scheme::BFV>& relin_key,
                           const ExecutionOptions& options = ExecutionOptions())
        {
            // TODO: Make it efficient
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Ciphertext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply(input1_, input2_, output_,
                                             options_inner);
                                    relinearize_inplace(output_, relin_key,
                                                        options_inner);
                                    one_minus_cipher_inplace(output_,
                                                             options_inner);
                                },
                                options);
                        },
                        options, (&input2 == &output));
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical NAND on two ciphertexts.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Second input ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void
        NAND_inplace(Ciphertext<Scheme::BFV>& input1,
                     Ciphertext<Scheme::BFV>& input2,
                     Relinkey<Scheme::BFV>& relin_key,
                     const ExecutionOptions& options = ExecutionOptions())
        {
            NAND(input1, input2, input1, relin_key, options);
        }

        /**
         * @brief Performs logical NAND on a ciphertext and a plaintext.
         *
         * @param input1 Input ciphertext.
         * @param input2 Input plaintext.
         * @param output Output ciphertext.
         * @param options Execution options.
         */
        __host__ void NAND(Ciphertext<Scheme::BFV>& input1,
                           Plaintext<Scheme::BFV>& input2,
                           Ciphertext<Scheme::BFV>& output,
                           const ExecutionOptions& options = ExecutionOptions())
        {
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply_plain(input1_, input2_, output_,
                                                   options_inner);
                                    one_minus_cipher_inplace(output_,
                                                             options_inner);
                                },
                                options);
                        },
                        options, false);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical NAND on a ciphertext and a
         * plaintext.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Input plaintext.
         * @param options Execution options.
         */
        __host__ void
        NAND_inplace(Ciphertext<Scheme::BFV>& input1,
                     Plaintext<Scheme::BFV>& input2,
                     const ExecutionOptions& options = ExecutionOptions())
        {
            NAND(input1, input2, input1, options);
        }

        /**
         * @brief Performs logical NOR on two ciphertexts.
         *
         * @param input1 First input ciphertext.
         * @param input2 Second input ciphertext.
         * @param output Output ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void NOR(Ciphertext<Scheme::BFV>& input1,
                          Ciphertext<Scheme::BFV>& input2,
                          Ciphertext<Scheme::BFV>& output,
                          Relinkey<Scheme::BFV>& relin_key,
                          const ExecutionOptions& options = ExecutionOptions())
        {
            // TODO: Make it efficient
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            Ciphertext<Scheme::BFV> inner_input1 =
                operator_from_ciphertext(input1, options.stream_);
            Ciphertext<Scheme::BFV> inner_input2 =
                operator_from_ciphertext(input1, options.stream_);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Ciphertext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply(input1_, input2_, inner_input1,
                                             options_inner);
                                    relinearize_inplace(inner_input1, relin_key,
                                                        options_inner);

                                    add(input1_, input2_, inner_input2,
                                        options_inner);

                                    sub(inner_input2, inner_input1, output_,
                                        options_inner);

                                    one_minus_cipher_inplace(output_,
                                                             options_inner);
                                },
                                options);
                        },
                        options, (&input2 == &output));
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical NOR on two ciphertexts.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Second input ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void
        NOR_inplace(Ciphertext<Scheme::BFV>& input1,
                    Ciphertext<Scheme::BFV>& input2,
                    Relinkey<Scheme::BFV>& relin_key,
                    const ExecutionOptions& options = ExecutionOptions())
        {
            NOR(input1, input2, input1, relin_key, options);
        }

        /**
         * @brief Performs logical NOR on a ciphertext and a plaintext.
         *
         * @param input1 Input ciphertext.
         * @param input2 Input plaintext.
         * @param output Output ciphertext.
         * @param options Execution options.
         */
        __host__ void NOR(Ciphertext<Scheme::BFV>& input1,
                          Plaintext<Scheme::BFV>& input2,
                          Ciphertext<Scheme::BFV>& output,
                          const ExecutionOptions& options = ExecutionOptions())
        {
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            Ciphertext<Scheme::BFV> inner_input1 =
                operator_from_ciphertext(input1, options.stream_);
            Ciphertext<Scheme::BFV> inner_input2 =
                operator_from_ciphertext(input1, options.stream_);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply_plain(input1_, input2_,
                                                   inner_input1, options_inner);

                                    add_plain(input1_, input2_, inner_input2,
                                              options_inner);

                                    sub(inner_input2, inner_input1, output_,
                                        options_inner);

                                    one_minus_cipher_inplace(output_,
                                                             options_inner);
                                },
                                options);
                        },
                        options, false);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical NOR on a ciphertext and a plaintext.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Input plaintext.
         * @param options Execution options.
         */
        __host__ void
        NOR_inplace(Ciphertext<Scheme::BFV>& input1,
                    Plaintext<Scheme::BFV>& input2,
                    const ExecutionOptions& options = ExecutionOptions())
        {
            NOR(input1, input2, input1, options);
        }

        /**
         * @brief Performs logical XNOR on two ciphertexts.
         *
         * @param input1 First input ciphertext.
         * @param input2 Second input ciphertext.
         * @param output Output ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void XNOR(Ciphertext<Scheme::BFV>& input1,
                           Ciphertext<Scheme::BFV>& input2,
                           Ciphertext<Scheme::BFV>& output,
                           Relinkey<Scheme::BFV>& relin_key,
                           const ExecutionOptions& options = ExecutionOptions())
        {
            // TODO: Make it efficient
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            Ciphertext<Scheme::BFV> inner_input1 =
                operator_from_ciphertext(input1, options.stream_);
            Ciphertext<Scheme::BFV> inner_input2 =
                operator_from_ciphertext(input1, options.stream_);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Ciphertext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply(input1_, input2_, inner_input1,
                                             options_inner);
                                    relinearize_inplace(inner_input1, relin_key,
                                                        options_inner);
                                    add(inner_input1, inner_input1,
                                        inner_input1, options_inner);

                                    add(input1_, input2_, inner_input2,
                                        options_inner);

                                    sub(inner_input2, inner_input1, output_,
                                        options_inner);

                                    one_minus_cipher_inplace(output_,
                                                             options_inner);
                                },
                                options);
                        },
                        options, (&input2 == &output));
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical XNOR on two ciphertexts.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Second input ciphertext.
         * @param relin_key Relinearization key.
         * @param options Execution options.
         */
        __host__ void
        XNOR_inplace(Ciphertext<Scheme::BFV>& input1,
                     Ciphertext<Scheme::BFV>& input2,
                     Relinkey<Scheme::BFV>& relin_key,
                     const ExecutionOptions& options = ExecutionOptions())
        {
            XNOR(input1, input2, input1, relin_key, options);
        }

        /**
         * @brief Performs logical XNOR on a ciphertext and a plaintext.
         *
         * @param input1 Input ciphertext.
         * @param input2 Input plaintext.
         * @param output Output ciphertext.
         * @param options Execution options.
         */
        __host__ void XNOR(Ciphertext<Scheme::BFV>& input1,
                           Plaintext<Scheme::BFV>& input2,
                           Ciphertext<Scheme::BFV>& output,
                           const ExecutionOptions& options = ExecutionOptions())
        {
            // TODO: Make it efficient
            ExecutionOptions options_inner =
                ExecutionOptions()
                    .set_stream(options.stream_)
                    .set_storage_type(storage_type::DEVICE)
                    .set_initial_location(true);

            Ciphertext<Scheme::BFV> inner_input1 =
                operator_from_ciphertext(input1, options.stream_);
            Ciphertext<Scheme::BFV> inner_input2 =
                operator_from_ciphertext(input1, options.stream_);

            input_storage_manager(
                input1,
                [&](Ciphertext<Scheme::BFV>& input1_)
                {
                    input_storage_manager(
                        input2,
                        [&](Plaintext<Scheme::BFV>& input2_)
                        {
                            output_storage_manager(
                                output,
                                [&](Ciphertext<Scheme::BFV>& output_)
                                {
                                    multiply_plain(input1_, input2_,
                                                   inner_input1, options_inner);
                                    add(inner_input1, inner_input1,
                                        inner_input1, options_inner);

                                    add_plain(input1_, input2_, inner_input2,
                                              options_inner);

                                    sub(inner_input2, inner_input1, output_,
                                        options_inner);

                                    one_minus_cipher_inplace(output_,
                                                             options_inner);
                                },
                                options);
                        },
                        options, false);
                },
                options, (&input1 == &output));
        }

        /**
         * @brief Performs in-place logical XNOR on a ciphertext and a
         * plaintext.
         *
         * @param input1 Ciphertext updated with result.
         * @param input2 Input plaintext.
         * @param options Execution options.
         */
        __host__ void
        XNOR_inplace(Ciphertext<Scheme::BFV>& input1,
                     Plaintext<Scheme::BFV>& input2,
                     const ExecutionOptions& options = ExecutionOptions())
        {
            XNOR(input1, input2, input1, options);
        }

        __host__ void
        one_minus_cipher(Ciphertext<Scheme::BFV>& input1,
                         Ciphertext<Scheme::BFV>& output,
                         const ExecutionOptions& options = ExecutionOptions());

        __host__ void one_minus_cipher_inplace(
            Ciphertext<Scheme::BFV>& input1,
            const ExecutionOptions& options = ExecutionOptions());

        // Encoded One
        DeviceVector<Data64> encoded_constant_one_;
    };

} // namespace heongpu

#endif // HEONGPU_BFV_OPERATOR_H
