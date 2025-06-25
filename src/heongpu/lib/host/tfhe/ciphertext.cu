// Copyright 2024-2025 Alişah Özcan
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Developer: Alişah Özcan

#include "tfhe/ciphertext.cuh"

namespace heongpu
{
    __host__
    Ciphertext<Scheme::TFHE>::Ciphertext(HEContext<Scheme::TFHE>& context,
                                         const ExecutionOptions& options)
    {
        n_ = context.n_;
        alpha_min_ = context.ks_stdev_;
        alpha_max_ = context.max_stdev_;

        storage_type_ = options.storage_;
    }

    void Ciphertext<Scheme::TFHE>::store_in_device(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            // pass
        }
        else
        {
            if (ciphertext_generated_)
            {
                a_device_location_ =
                    DeviceVector<int32_t>(a_host_location_, stream);
                a_host_location_.resize(0);
                a_host_location_.shrink_to_fit();

                b_device_location_ =
                    DeviceVector<int32_t>(b_host_location_, stream);
                b_host_location_.resize(0);
                b_host_location_.shrink_to_fit();
            }
            else
            {
                // pass
            }

            storage_type_ = storage_type::DEVICE;
        }
    }

    void Ciphertext<Scheme::TFHE>::store_in_host(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            if (ciphertext_generated_)
            {
                a_host_location_ =
                    HostVector<int32_t>(a_device_location_.size());
                cudaMemcpyAsync(a_host_location_.data(),
                                a_device_location_.data(),
                                a_device_location_.size() * sizeof(int32_t),
                                cudaMemcpyDeviceToHost, stream);
                HEONGPU_CUDA_CHECK(cudaGetLastError());

                a_device_location_.resize(0, stream);
                a_device_location_.shrink_to_fit(stream);

                b_host_location_ =
                    HostVector<int32_t>(b_device_location_.size());
                cudaMemcpyAsync(b_host_location_.data(),
                                b_device_location_.data(),
                                b_device_location_.size() * sizeof(int32_t),
                                cudaMemcpyDeviceToHost, stream);
                HEONGPU_CUDA_CHECK(cudaGetLastError());

                b_device_location_.resize(0, stream);
                b_device_location_.shrink_to_fit(stream);
            }
            else
            {
                // pass
            }

            storage_type_ = storage_type::HOST;
        }
        else
        {
            // pass
        }
    }

    void Ciphertext<Scheme::TFHE>::copy_to_device(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            // pass
        }
        else
        {
            if (ciphertext_generated_)
            {
                a_device_location_ =
                    DeviceVector<int32_t>(a_host_location_, stream);

                b_device_location_ =
                    DeviceVector<int32_t>(b_host_location_, stream);
            }
            else
            {
                // pass
            }

            storage_type_ = storage_type::DEVICE;
        }
    }

    void Ciphertext<Scheme::TFHE>::remove_from_device(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            a_device_location_.resize(0, stream);
            a_device_location_.shrink_to_fit(stream);

            b_device_location_.resize(0, stream);
            b_device_location_.shrink_to_fit(stream);

            storage_type_ = storage_type::HOST;
        }
        else
        {
            // pass
        }
    }

    void Ciphertext<Scheme::TFHE>::remove_from_host()
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            // pass
        }
        else
        {
            a_host_location_.resize(0);
            a_host_location_.shrink_to_fit();

            b_host_location_.resize(0);
            b_host_location_.shrink_to_fit();

            storage_type_ = storage_type::DEVICE;
        }
    }

} // namespace heongpu