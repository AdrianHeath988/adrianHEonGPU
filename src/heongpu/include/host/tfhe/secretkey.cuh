// Copyright 2024-2025 Alişah Özcan
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Developer: Alişah Özcan

#ifndef HEONGPU_TFHE_SECRETKEY_H
#define HEONGPU_TFHE_SECRETKEY_H

#include "tfhe/context.cuh"
#include "ntt.cuh"
#include "keygeneration.cuh"

namespace heongpu
{
    template <> class Secretkey<Scheme::TFHE>
    {
        template <Scheme S> friend class HEKeyGenerator;
        template <Scheme S> friend class HEEncryptor;
        template <Scheme S> friend class HEDecryptor;

        template <typename T, typename F>
        friend void input_storage_manager(T& object, F function,
                                          ExecutionOptions options,
                                          bool check_initial_condition);
        template <typename T, typename F>
        friend void input_vector_storage_manager(std::vector<T>& objects,
                                                 F function,
                                                 ExecutionOptions options,
                                                 bool is_input_output_same);

      public:
        __host__ Secretkey(HEContext<Scheme::TFHE>& context,
                           bool store_in_gpu = true);

        /**
         * @brief Stores the Secretkey in the device (GPU) memory.
         */
        void store_in_device(cudaStream_t stream = cudaStreamDefault);

        /**
         * @brief Stores the Secretkey in the host (CPU) memory.
         */
        void store_in_host(cudaStream_t stream = cudaStreamDefault);

        /**
         * @brief Checks whether the data is stored on the device (GPU) memory.
         */
        bool is_on_device() const noexcept
        {
            if (storage_type_ == storage_type::DEVICE)
            {
                return true;
            }
            else
            {
                return false;
            }
        }

        /**
         * @brief Switches the Ciphertext CUDA stream.
         *
         * @param stream The new CUDA stream to be used.
         */
        void switch_stream(cudaStream_t stream)
        {
            lwe_key_device_location_.set_stream(stream);
            tlwe_key_device_location_.set_stream(stream);
        }

        /**
         * @brief Retrieves the CUDA stream associated with the ciphertext.
         *
         * This function returns the CUDA stream that was used to create or last
         * modify the ciphertext.
         *
         * @return The CUDA stream associated with the ciphertext.
         */
        cudaStream_t stream() const noexcept
        {
            return lwe_key_device_location_.stream();
        }

        /**
         * @brief Indicates whether the secret key has been generated.
         *
         * @return true if the secret key has been generated, false otherwise.
         */
        inline bool is_generated() const noexcept
        {
            return secret_key_generated_;
        }

        Secretkey() = default;

        /**
         * @brief Copy constructor for creating a new Secretkey object by
         * copying an existing one.
         *
         * This constructor performs a deep copy of the secret key data,
         * ensuring that the new object has its own independent copy of the
         * data. GPU memory operations are handled using `cudaMemcpyAsync` for
         * asynchronous data transfer.
         *
         * @param copy The source Secretkey object to copy from.
         */
        Secretkey(const Secretkey& copy)
            : n_(copy.n_), lwe_alpha_min(copy.lwe_alpha_min),
              lwe_alpha_max(copy.lwe_alpha_max), N_(copy.N_), k_(copy.k_),
              tlwe_alpha_min(copy.tlwe_alpha_min),
              tlwe_alpha_max(copy.tlwe_alpha_max), bk_l_(copy.bk_l_),
              bk_bg_bit_(copy.bk_bg_bit_), bg_(copy.bg_),
              half_bg_(copy.half_bg_), mask_mod_(copy.mask_mod_),
              kpl_(copy.kpl_), h_(copy.h_), offset_(copy.offset_),
              secret_key_generated_(copy.secret_key_generated_),
              storage_type_(copy.storage_type_)
        {
            if (copy.secret_key_generated_)
            {
                if (copy.storage_type_ == storage_type::DEVICE)
                {
                    lwe_key_device_location_.resize(
                        copy.lwe_key_device_location_.size(),
                        copy.lwe_key_device_location_.stream());
                    cudaMemcpyAsync(
                        lwe_key_device_location_.data(),
                        copy.lwe_key_device_location_.data(),
                        copy.lwe_key_device_location_.size() * sizeof(int32_t),
                        cudaMemcpyDeviceToDevice,
                        copy.lwe_key_device_location_
                            .stream()); // TODO: use cudaStreamPerThread

                    tlwe_key_device_location_.resize(
                        copy.tlwe_key_device_location_.size(),
                        copy.tlwe_key_device_location_.stream());
                    cudaMemcpyAsync(
                        tlwe_key_device_location_.data(),
                        copy.tlwe_key_device_location_.data(),
                        copy.tlwe_key_device_location_.size() * sizeof(int32_t),
                        cudaMemcpyDeviceToDevice,
                        copy.tlwe_key_device_location_
                            .stream()); // TODO: use cudaStreamPerThread
                }
                else
                {
                    std::memcpy(lwe_key_host_location_.data(),
                                copy.lwe_key_host_location_.data(),
                                copy.lwe_key_host_location_.size() *
                                    sizeof(int32_t));

                    std::memcpy(tlwe_key_host_location_.data(),
                                copy.tlwe_key_host_location_.data(),
                                copy.tlwe_key_host_location_.size() *
                                    sizeof(int32_t));
                }
            }
        }

        /**
         * @brief Move constructor for transferring ownership of a Secretkey
         * object.
         *
         * Transfers all resources, including GPU memory, from the source object
         * to the newly constructed object. The source object is left in a valid
         * but undefined state.
         *
         * @param assign The source Secretkey object to move from.
         */
        Secretkey(Secretkey&& assign) noexcept
            : n_(std::move(assign.n_)),
              lwe_alpha_min(std::move(assign.lwe_alpha_min)),
              lwe_alpha_max(std::move(assign.lwe_alpha_max)),
              N_(std::move(assign.N_)), k_(std::move(assign.k_)),
              tlwe_alpha_min(std::move(assign.tlwe_alpha_min)),
              tlwe_alpha_max(std::move(assign.tlwe_alpha_max)),
              bk_l_(std::move(assign.bk_l_)),
              bk_bg_bit_(std::move(assign.bk_bg_bit_)),
              bg_(std::move(assign.bg_)), half_bg_(std::move(assign.half_bg_)),
              mask_mod_(std::move(assign.mask_mod_)),
              kpl_(std::move(assign.kpl_)), h_(std::move(assign.h_)),
              offset_(std::move(assign.offset_)),
              secret_key_generated_(std::move(assign.secret_key_generated_)),
              storage_type_(std::move(assign.storage_type_)),
              lwe_key_device_location_(
                  std::move(assign.lwe_key_device_location_)),
              lwe_key_host_location_(std::move(assign.lwe_key_host_location_)),
              tlwe_key_device_location_(
                  std::move(assign.tlwe_key_device_location_)),
              tlwe_key_host_location_(std::move(assign.tlwe_key_host_location_))
        {
        }

        /**
         * @brief Copy assignment operator for assigning one Secretkey object to
         * another.
         *
         * Performs a deep copy of the secret key data, ensuring that the target
         * object has its own independent copy. GPU memory is copied using
         * `cudaMemcpyAsync`.
         *
         * @param copy The source Secretkey object to copy from.
         * @return Reference to the assigned object.
         */
        Secretkey& operator=(const Secretkey& copy)
        {
            if (this != &copy)
            {
                n_ = copy.n_;
                lwe_alpha_min = copy.lwe_alpha_min;
                lwe_alpha_max = copy.lwe_alpha_max;
                N_ = copy.N_;
                k_ = copy.k_;
                tlwe_alpha_min = copy.tlwe_alpha_min;
                tlwe_alpha_max = copy.tlwe_alpha_max;
                bk_l_ = copy.bk_l_;
                bk_bg_bit_ = copy.bk_bg_bit_;
                bg_ = copy.bg_;
                half_bg_ = copy.half_bg_;
                mask_mod_ = copy.mask_mod_;
                kpl_ = copy.kpl_;
                h_ = copy.h_;
                offset_ = copy.offset_;
                secret_key_generated_ = copy.secret_key_generated_;
                storage_type_ = copy.storage_type_;

                if (copy.secret_key_generated_)
                {
                    if (copy.storage_type_ == storage_type::DEVICE)
                    {
                        lwe_key_device_location_.resize(
                            copy.lwe_key_device_location_.size(),
                            copy.lwe_key_device_location_.stream());
                        cudaMemcpyAsync(
                            lwe_key_device_location_.data(),
                            copy.lwe_key_device_location_.data(),
                            copy.lwe_key_device_location_.size() *
                                sizeof(int32_t),
                            cudaMemcpyDeviceToDevice,
                            copy.lwe_key_device_location_
                                .stream()); // TODO: use cudaStreamPerThread

                        tlwe_key_device_location_.resize(
                            copy.tlwe_key_device_location_.size(),
                            copy.tlwe_key_device_location_.stream());
                        cudaMemcpyAsync(
                            tlwe_key_device_location_.data(),
                            copy.tlwe_key_device_location_.data(),
                            copy.tlwe_key_device_location_.size() *
                                sizeof(int32_t),
                            cudaMemcpyDeviceToDevice,
                            copy.tlwe_key_device_location_
                                .stream()); // TODO: use cudaStreamPerThread
                    }
                    else
                    {
                        std::memcpy(lwe_key_host_location_.data(),
                                    copy.lwe_key_host_location_.data(),
                                    copy.lwe_key_host_location_.size() *
                                        sizeof(int32_t));

                        std::memcpy(tlwe_key_host_location_.data(),
                                    copy.tlwe_key_host_location_.data(),
                                    copy.tlwe_key_host_location_.size() *
                                        sizeof(int32_t));
                    }
                }
            }
            return *this;
        }

        /**
         * @brief Move assignment operator for transferring ownership of a
         * Secretkey object.
         *
         * Transfers all resources, including GPU memory, from the source object
         * to the target object. The source object is left in a valid but
         * undefined state.
         *
         * @param assign The source Secretkey object to move from.
         * @return Reference to the assigned object.
         */
        Secretkey& operator=(Secretkey&& assign) noexcept
        {
            if (this != &assign)
            {
                n_ = std::move(assign.n_);
                lwe_alpha_min = std::move(assign.lwe_alpha_min);
                lwe_alpha_max = std::move(assign.lwe_alpha_max);
                N_ = std::move(assign.N_);
                k_ = std::move(assign.k_);
                tlwe_alpha_min = std::move(assign.tlwe_alpha_min);
                tlwe_alpha_max = std::move(assign.tlwe_alpha_max);
                bk_l_ = std::move(assign.bk_l_);
                bk_bg_bit_ = std::move(assign.bk_bg_bit_);
                bg_ = std::move(assign.bg_);
                half_bg_ = std::move(assign.half_bg_);
                mask_mod_ = std::move(assign.mask_mod_);
                kpl_ = std::move(assign.kpl_);
                h_ = std::move(assign.h_);
                offset_ = std::move(assign.offset_);
                secret_key_generated_ = std::move(assign.secret_key_generated_);
                storage_type_ = std::move(assign.storage_type_);
                lwe_key_device_location_ =
                    std::move(assign.lwe_key_device_location_);
                lwe_key_host_location_ =
                    std::move(assign.lwe_key_host_location_);
                tlwe_key_device_location_ =
                    std::move(assign.tlwe_key_device_location_);
                tlwe_key_host_location_ =
                    std::move(assign.tlwe_key_host_location_);
            }
            return *this;
        }

      private:
        const scheme_type scheme_ = scheme_type::tfhe;

        // LWE Context
        int n_;
        int lwe_alpha_min;
        int lwe_alpha_max;

        DeviceVector<int32_t> lwe_key_device_location_;
        HostVector<int32_t> lwe_key_host_location_;

        // TLWE Context
        int N_;
        int k_;
        int tlwe_alpha_min;
        int tlwe_alpha_max;
        // extracted_lwe_params

        DeviceVector<int32_t> tlwe_key_device_location_;
        HostVector<int32_t> tlwe_key_host_location_;

        // TGSW Context
        int bk_l_;
        int bk_bg_bit_;
        int bg_;
        int half_bg_;
        int mask_mod_;
        // tlwe_params = TLWE Context
        int kpl_;
        std::vector<int> h_;
        int offset_;

        bool secret_key_generated_ = false;
        storage_type storage_type_;

        void copy_to_device(cudaStream_t stream);
        void remove_from_device(cudaStream_t stream);
        void remove_from_host();
    };

} // namespace heongpu
#endif // HEONGPU_TFHE_SECRETKEY_H