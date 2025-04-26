// Copyright 2024-2025 Alişah Özcan
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Developer: Alişah Özcan

#include "bfv/evaluationkey.cuh"

namespace heongpu
{
    __host__ Relinkey<Scheme::BFV>::Relinkey(HEContext<Scheme::BFV>& context,
                                             bool store_in_gpu)
    {
        if (!context.context_generated_)
        {
            throw std::invalid_argument("HEContext is not generated!");
        }

        scheme_ = context.scheme_;
        key_type = context.keyswitching_type_;

        ring_size = context.n;
        Q_prime_size_ = context.Q_prime_size;
        Q_size_ = context.Q_size;

        storage_type_ =
            store_in_gpu ? storage_type::DEVICE : storage_type::HOST;

        switch (static_cast<int>(context.keyswitching_type_))
        {
            case 1: // KEYSWITCHING_METHOD_I
            {
                relinkey_size_ = 2 * Q_size_ * Q_prime_size_ * ring_size;
            }
            break;
            case 2: // KEYSWITCHING_METHOD_II
            {
                d_ = context.d;
                relinkey_size_ = 2 * d_ * Q_prime_size_ * ring_size;
            }
            break;
            case 3: // KEYSWITCHING_METHOD_III
            {
                d_ = context.d;
                d_tilda_ = context.d_tilda;
                r_prime_ = context.r_prime;
                relinkey_size_ = 2 * d_ * d_tilda_ * r_prime_ * ring_size;
            }
            break;
            default:
                break;
        }
    }

    void Relinkey<Scheme::BFV>::store_in_device(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            // pass
        }
        else
        {
            device_location_ = DeviceVector<Data64>(host_location_, stream);
            host_location_.resize(0);
            host_location_.shrink_to_fit();

            storage_type_ = storage_type::DEVICE;
        }
    }

    void Relinkey<Scheme::BFV>::store_in_host(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            host_location_ = HostVector<Data64>(relinkey_size_);
            cudaMemcpyAsync(host_location_.data(), device_location_.data(),
                            relinkey_size_ * sizeof(Data64),
                            cudaMemcpyDeviceToHost, stream);
            HEONGPU_CUDA_CHECK(cudaGetLastError());

            device_location_.resize(0, stream);

            storage_type_ = storage_type::HOST;
        }
        else
        {
            // pass
        }
    }

    Data64* Relinkey<Scheme::BFV>::data()
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            return device_location_.data();
        }
        else
        {
            return host_location_.data();
        }
    }

    void Relinkey<Scheme::BFV>::save(std::ostream& os) const
    {
        if (relin_key_generated_)
        {
            os.write((char*) &scheme_, sizeof(scheme_));

            os.write((char*) &key_type, sizeof(key_type));

            os.write((char*) &ring_size, sizeof(ring_size));

            os.write((char*) &Q_prime_size_, sizeof(Q_prime_size_));

            os.write((char*) &Q_size_, sizeof(Q_size_));

            os.write((char*) &d_, sizeof(d_));

            os.write((char*) &d_tilda_, sizeof(d_tilda_));

            os.write((char*) &r_prime_, sizeof(r_prime_));

            os.write((char*) &storage_type_, sizeof(storage_type_));

            os.write((char*) &relin_key_generated_,
                     sizeof(relin_key_generated_));

            os.write((char*) &relinkey_size_, sizeof(relinkey_size_));

            if (storage_type_ == storage_type::DEVICE)
            {
                HostVector<Data64> host_locations_temp(relinkey_size_);
                cudaMemcpy(host_locations_temp.data(), device_location_.data(),
                           relinkey_size_ * sizeof(Data64),
                           cudaMemcpyDeviceToHost);
                HEONGPU_CUDA_CHECK(cudaGetLastError());
                cudaDeviceSynchronize();

                os.write((char*) host_locations_temp.data(),
                         sizeof(Data64) * relinkey_size_);
            }
            else
            {
                os.write((char*) host_location_.data(),
                         sizeof(Data64) * relinkey_size_);
            }
        }
        else
        {
            throw std::runtime_error(
                "Relinkey is not generated so can not be serialized!");
        }
    }

    void Relinkey<Scheme::BFV>::load(std::istream& is)
    {
        if ((!relin_key_generated_))
        {
            is.read((char*) &scheme_, sizeof(scheme_));

            if (scheme_ != scheme_type::bfv)
            {
                throw std::runtime_error("Invalid scheme binary!");
            }

            is.read((char*) &key_type, sizeof(key_type));

            is.read((char*) &ring_size, sizeof(ring_size));

            is.read((char*) &Q_prime_size_, sizeof(Q_prime_size_));

            is.read((char*) &Q_size_, sizeof(Q_size_));

            is.read((char*) &d_, sizeof(d_));

            is.read((char*) &d_tilda_, sizeof(d_tilda_));

            is.read((char*) &r_prime_, sizeof(r_prime_));

            is.read((char*) &storage_type_, sizeof(storage_type_));

            is.read((char*) &relin_key_generated_,
                    sizeof(relin_key_generated_));

            is.read((char*) &relinkey_size_, sizeof(relinkey_size_));

            storage_type_ = storage_type::DEVICE;
            relin_key_generated_ = true;

            HostVector<Data64> host_locations_temp(relinkey_size_);
            is.read((char*) host_locations_temp.data(),
                    sizeof(Data64) * relinkey_size_);

            device_location_.resize(relinkey_size_);
            cudaMemcpy(device_location_.data(), host_locations_temp.data(),
                       relinkey_size_ * sizeof(Data64), cudaMemcpyHostToDevice);
            HEONGPU_CUDA_CHECK(cudaGetLastError());
            cudaDeviceSynchronize();
        }
        else
        {
            throw std::runtime_error("Relinkey has been already exist!");
        }
    }

    int Relinkey<Scheme::BFV>::memory_size()
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            return device_location_.size();
        }
        else
        {
            return host_location_.size();
        }
    }

    void Relinkey<Scheme::BFV>::memory_clear(cudaStream_t stream)
    {
        if (device_location_.size() > 0)
        {
            device_location_.resize(0, stream);
            device_location_.shrink_to_fit(stream);
        }

        if (host_location_.size() > 0)
        {
            host_location_.resize(0);
            host_location_.shrink_to_fit();
        }
    }

    void
    Relinkey<Scheme::BFV>::memory_set(DeviceVector<Data64>&& new_device_vector)
    {
        storage_type_ = storage_type::DEVICE;
        device_location_ = std::move(new_device_vector);

        if (host_location_.size() > 0)
        {
            host_location_.resize(0);
            host_location_.shrink_to_fit();
        }
    }

    void Relinkey<Scheme::BFV>::copy_to_device(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            // pass
        }
        else
        {
            if (memory_size() == 0)
            {
                // pass
            }
            else
            {
                device_location_ = DeviceVector<Data64>(host_location_, stream);
            }

            storage_type_ = storage_type::DEVICE;
        }
    }

    void Relinkey<Scheme::BFV>::remove_from_device(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            device_location_.resize(0, stream);
            device_location_.shrink_to_fit(stream);

            storage_type_ = storage_type::HOST;
        }
        else
        {
            // pass
        }
    }

    void Relinkey<Scheme::BFV>::remove_from_host()
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            // pass
        }
        else
        {
            host_location_.resize(0);
            host_location_.shrink_to_fit();

            storage_type_ = storage_type::DEVICE;
        }
    }

    __host__ MultipartyRelinkey<Scheme::BFV>::MultipartyRelinkey(
        HEContext<Scheme::BFV>& context, const RNGSeed seed, bool store_in_gpu)
        : Relinkey(context, store_in_gpu), seed_(seed)
    {
    }

    __host__ Galoiskey<Scheme::BFV>::Galoiskey(HEContext<Scheme::BFV>& context,
                                               bool store_in_gpu)
    {
        if (!context.context_generated_)
        {
            throw std::invalid_argument("HEContext is not generated!");
        }

        scheme_ = context.scheme_;
        key_type = context.keyswitching_type_;

        ring_size = context.n;
        Q_prime_size_ = context.Q_prime_size;
        Q_size_ = context.Q_size;

        storage_type_ =
            store_in_gpu ? storage_type::DEVICE : storage_type::HOST;

        customized = false;

        group_order_ = 3;

        switch (static_cast<int>(context.keyswitching_type_))
        {
            case 1: // KEYSWITCHING_METHOD_I
            {
                galoiskey_size_ = 2 * Q_size_ * Q_prime_size_ * ring_size;

                for (int i = 0; i < MAX_SHIFT; i++)
                {
                    int power = pow(2, i);
                    galois_elt[power] =
                        steps_to_galois_elt(power, ring_size, group_order_);
                    galois_elt[(-power)] =
                        steps_to_galois_elt((-power), ring_size, group_order_);
                }

                galois_elt_zero =
                    steps_to_galois_elt(0, ring_size, group_order_);
            }
            break;
            case 2: // KEYSWITCHING_METHOD_II
            {
                for (int i = 0; i < MAX_SHIFT; i++)
                {
                    int power = pow(2, i);
                    galois_elt[power] =
                        steps_to_galois_elt(power, ring_size, group_order_);
                    galois_elt[(-power)] =
                        steps_to_galois_elt((-power), ring_size, group_order_);
                }

                galois_elt_zero =
                    steps_to_galois_elt(0, ring_size, group_order_);

                d_ = context.d;
                galoiskey_size_ = 2 * d_ * Q_prime_size_ * ring_size;
            }
            break;
            case 3: // KEYSWITCHING_METHOD_III
                throw std::invalid_argument(
                    "Galoiskey does not support KEYSWITCHING_METHOD_III");
                break;
            default:
                throw std::invalid_argument("Invalid Key Switching Type");
                break;
        }
    }

    __host__ Galoiskey<Scheme::BFV>::Galoiskey(HEContext<Scheme::BFV>& context,
                                               std::vector<int>& shift_vec,
                                               bool store_in_gpu)
    {
        if (!context.context_generated_)
        {
            throw std::invalid_argument("HEContext is not generated!");
        }

        scheme_ = context.scheme_;
        key_type = context.keyswitching_type_;

        ring_size = context.n;
        Q_prime_size_ = context.Q_prime_size;
        Q_size_ = context.Q_size;

        storage_type_ =
            store_in_gpu ? storage_type::DEVICE : storage_type::HOST;

        customized = false;

        group_order_ = 3;

        switch (static_cast<int>(context.keyswitching_type_))
        {
            case 1: // KEYSWITCHING_METHOD_I
            {
                galoiskey_size_ = 2 * Q_size_ * Q_prime_size_ * ring_size;

                for (int shift : shift_vec)
                {
                    galois_elt[shift] =
                        steps_to_galois_elt(shift, ring_size, group_order_);
                }

                galois_elt_zero =
                    steps_to_galois_elt(0, ring_size, group_order_);
            }
            break;
            case 2: // KEYSWITCHING_METHOD_II
            {
                for (int shift : shift_vec)
                {
                    galois_elt[shift] =
                        steps_to_galois_elt(shift, ring_size, group_order_);
                }

                galois_elt_zero =
                    steps_to_galois_elt(0, ring_size, group_order_);

                d_ = context.d;
                galoiskey_size_ = 2 * d_ * Q_prime_size_ * ring_size;
            }
            break;
            case 3: // KEYSWITCHING_METHOD_III Galoiskey
                throw std::invalid_argument(
                    "Galoiskey does not support KEYSWITCHING_METHOD_III");
                break;
            default:
                throw std::invalid_argument("Invalid Key Switching Type");
                break;
        }
    }

    __host__
    Galoiskey<Scheme::BFV>::Galoiskey(HEContext<Scheme::BFV>& context,
                                      std::vector<uint32_t>& galois_elts,
                                      bool store_in_gpu)
    {
        if (!context.context_generated_)
        {
            throw std::invalid_argument("HEContext is not generated!");
        }

        scheme_ = context.scheme_;
        key_type = context.keyswitching_type_;

        ring_size = context.n;
        Q_prime_size_ = context.Q_prime_size;
        Q_size_ = context.Q_size;

        storage_type_ =
            store_in_gpu ? storage_type::DEVICE : storage_type::HOST;

        customized = true;

        group_order_ = 3;

        switch (static_cast<int>(context.keyswitching_type_))
        {
            case 1: // KEYSWITCHING_METHOD_I
            {
                galois_elt_zero =
                    steps_to_galois_elt(0, ring_size, group_order_);
                galoiskey_size_ = 2 * Q_size_ * Q_prime_size_ * ring_size;
                custom_galois_elt = galois_elts;
            }
            break;
            case 2: // KEYSWITCHING_METHOD_II
            {
                d_ = context.d;
                galois_elt_zero =
                    steps_to_galois_elt(0, ring_size, group_order_);
                galoiskey_size_ = 2 * d_ * Q_prime_size_ * ring_size;
                custom_galois_elt = galois_elts;
            }
            break;
            case 3: // KEYSWITCHING_METHOD_III Galoiskey
                throw std::invalid_argument(
                    "Galoiskey does not support KEYSWITCHING_METHOD_III");
                break;
            default:
                throw std::invalid_argument("Invalid Key Switching Type");
                break;
        }
    }

    void Galoiskey<Scheme::BFV>::store_in_device(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            // pass
        }
        else
        {
            for (const auto& galois_ : host_location_)
            {
                device_location_[galois_.first] =
                    DeviceVector<Data64>(galois_.second, stream);
            }

            zero_device_location_ =
                DeviceVector<Data64>(zero_host_location_, stream);

            host_location_.clear();
            zero_host_location_.resize(0);
            zero_host_location_.shrink_to_fit();

            storage_type_ = storage_type::DEVICE;
        }
    }

    void Galoiskey<Scheme::BFV>::store_in_host(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            for (auto& galois_ : device_location_)
            {
                host_location_[galois_.first] =
                    HostVector<Data64>(galoiskey_size_);
                cudaMemcpyAsync(host_location_[galois_.first].data(),
                                galois_.second.data(),
                                galoiskey_size_ * sizeof(Data64),
                                cudaMemcpyDeviceToHost, stream);
                HEONGPU_CUDA_CHECK(cudaGetLastError());

                galois_.second.resize(0, stream);
            }

            zero_host_location_ = HostVector<Data64>(galoiskey_size_);
            cudaMemcpyAsync(zero_host_location_.data(),
                            zero_device_location_.data(),
                            galoiskey_size_ * sizeof(Data64),
                            cudaMemcpyDeviceToHost, stream);
            HEONGPU_CUDA_CHECK(cudaGetLastError());

            device_location_.clear();
            zero_device_location_.resize(0);

            storage_type_ = storage_type::HOST;
        }
        else
        {
            // pass
        }
    }

    Data64* Galoiskey<Scheme::BFV>::data(size_t i)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            return device_location_[i].data();
        }
        else
        {
            return host_location_[i].data();
        }
    }

    Data64* Galoiskey<Scheme::BFV>::c_data()
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            return zero_device_location_.data();
        }
        else
        {
            return zero_host_location_.data();
        }
    }

    void Galoiskey<Scheme::BFV>::save(std::ostream& os) const
    {
        if (galois_key_generated_)
        {
            os.write((char*) &scheme_, sizeof(scheme_));

            os.write((char*) &key_type, sizeof(key_type));

            os.write((char*) &ring_size, sizeof(ring_size));

            os.write((char*) &Q_prime_size_, sizeof(Q_prime_size_));

            os.write((char*) &Q_size_, sizeof(Q_size_));

            os.write((char*) &d_, sizeof(d_));

            os.write((char*) &customized, sizeof(customized));

            os.write((char*) &group_order_, sizeof(group_order_));

            os.write((char*) &storage_type_, sizeof(storage_type_));

            os.write((char*) &galois_key_generated_,
                     sizeof(galois_key_generated_));

            if (customized)
            {
                uint32_t custom_galois_elt_size = custom_galois_elt.size();
                os.write((char*) &custom_galois_elt_size,
                         sizeof(custom_galois_elt_size));
                os.write((char*) custom_galois_elt.data(),
                         sizeof(u_int32_t) * custom_galois_elt_size);
            }
            else
            {
                uint32_t galois_elt_size = galois_elt.size();
                os.write((char*) &galois_elt_size, sizeof(galois_elt_size));
                for (auto& galois : galois_elt)
                {
                    os.write((char*) &galois.first, sizeof(galois.first));
                    os.write((char*) &galois.second, sizeof(galois.second));
                }
            }

            os.write((char*) &galois_elt_zero, sizeof(galois_elt_zero));

            os.write((char*) &galoiskey_size_, sizeof(galoiskey_size_));

            if (storage_type_ == storage_type::DEVICE)
            {
                uint32_t key_count = device_location_.size();
                os.write((char*) &key_count, sizeof(key_count));

                for (auto& galois_key_mem : device_location_)
                {
                    HostVector<Data64> host_locations_temp(galoiskey_size_);
                    cudaMemcpy(host_locations_temp.data(),
                               galois_key_mem.second.data(),
                               galoiskey_size_ * sizeof(Data64),
                               cudaMemcpyDeviceToHost);
                    HEONGPU_CUDA_CHECK(cudaGetLastError());
                    cudaDeviceSynchronize();

                    os.write((char*) &galois_key_mem.first,
                             sizeof(galois_key_mem.first));
                    os.write((char*) host_locations_temp.data(),
                             sizeof(Data64) * galoiskey_size_);
                }

                HostVector<Data64> host_locations_temp(galoiskey_size_);
                cudaMemcpy(
                    host_locations_temp.data(), zero_device_location_.data(),
                    galoiskey_size_ * sizeof(Data64), cudaMemcpyDeviceToHost);
                HEONGPU_CUDA_CHECK(cudaGetLastError());
                cudaDeviceSynchronize();

                os.write((char*) host_locations_temp.data(),
                         sizeof(Data64) * galoiskey_size_);
            }
            else
            {
                uint32_t key_count = host_location_.size();
                os.write((char*) &key_count, sizeof(key_count));

                for (auto& galois_key_mem : host_location_)
                {
                    os.write((char*) &galois_key_mem.first,
                             sizeof(galois_key_mem.first));
                    os.write((char*) galois_key_mem.second.data(),
                             sizeof(Data64) * galoiskey_size_);
                }

                os.write((char*) zero_host_location_.data(),
                         sizeof(Data64) * galoiskey_size_);
            }
        }
        else
        {
            throw std::runtime_error(
                "Galoiskey is not generated so can not be serialized!");
        }
    }

    void Galoiskey<Scheme::BFV>::load(std::istream& is)
    {
        if ((!galois_key_generated_))
        {
            is.read((char*) &scheme_, sizeof(scheme_));

            if (scheme_ != scheme_type::bfv)
            {
                throw std::runtime_error("Invalid scheme binary!");
            }

            is.read((char*) &key_type, sizeof(key_type));

            is.read((char*) &ring_size, sizeof(ring_size));

            is.read((char*) &Q_prime_size_, sizeof(Q_prime_size_));

            is.read((char*) &Q_size_, sizeof(Q_size_));

            is.read((char*) &d_, sizeof(d_));

            is.read((char*) &customized, sizeof(customized));

            is.read((char*) &group_order_, sizeof(group_order_));

            is.read((char*) &storage_type_, sizeof(storage_type_));

            is.read((char*) &galois_key_generated_,
                    sizeof(galois_key_generated_));

            storage_type_ = storage_type::DEVICE;
            galois_key_generated_ = true;

            if (customized)
            {
                uint32_t custom_galois_elt_size;
                is.read((char*) &custom_galois_elt_size,
                        sizeof(custom_galois_elt_size));
                custom_galois_elt.resize(custom_galois_elt_size);
                is.read((char*) custom_galois_elt.data(),
                        sizeof(u_int32_t) * custom_galois_elt_size);
            }
            else
            {
                uint32_t galois_elt_size;
                is.read((char*) &galois_elt_size, sizeof(galois_elt_size));
                for (int i = 0; i < galois_elt_size; i++)
                {
                    int first;
                    int second;
                    is.read((char*) &first, sizeof(first));
                    is.read((char*) &second, sizeof(second));
                    galois_elt[first] = second;
                }
            }

            is.read((char*) &galois_elt_zero, sizeof(galois_elt_zero));

            is.read((char*) &galoiskey_size_, sizeof(galoiskey_size_));

            uint32_t key_count;
            is.read((char*) &key_count, sizeof(key_count));

            for (int i = 0; i < key_count; i++)
            {
                int first;
                is.read((char*) &first, sizeof(first));
                HostVector<Data64> host_locations_temp(galoiskey_size_);
                is.read((char*) host_locations_temp.data(),
                        sizeof(Data64) * galoiskey_size_);
                device_location_[first] =
                    DeviceVector<Data64>(host_locations_temp);
                cudaDeviceSynchronize();
            }

            HostVector<Data64> host_locations_temp(galoiskey_size_);
            is.read((char*) host_locations_temp.data(),
                    sizeof(Data64) * galoiskey_size_);

            zero_device_location_.resize(galoiskey_size_);
            cudaMemcpy(zero_device_location_.data(), host_locations_temp.data(),
                       galoiskey_size_ * sizeof(Data64),
                       cudaMemcpyHostToDevice);
            HEONGPU_CUDA_CHECK(cudaGetLastError());
            cudaDeviceSynchronize();
        }
        else
        {
            throw std::runtime_error("Galoiskey has been already exist!");
        }
    }

    __host__ MultipartyGaloiskey<Scheme::BFV>::MultipartyGaloiskey(
        HEContext<Scheme::BFV>& context, const RNGSeed seed, bool store_in_gpu)
        : Galoiskey(context, store_in_gpu), seed_(seed)
    {
    }

    __host__ MultipartyGaloiskey<Scheme::BFV>::MultipartyGaloiskey(
        HEContext<Scheme::BFV>& context, std::vector<int>& shift_vec,
        const RNGSeed seed, bool store_in_gpu)
        : Galoiskey(context, shift_vec, store_in_gpu), seed_(seed)
    {
    }

    __host__ MultipartyGaloiskey<Scheme::BFV>::MultipartyGaloiskey(
        HEContext<Scheme::BFV>& context, std::vector<uint32_t>& galois_elts,
        const RNGSeed seed, bool store_in_gpu)
        : Galoiskey(context, galois_elts, store_in_gpu), seed_(seed)
    {
    }

    __host__ Switchkey<Scheme::BFV>::Switchkey(HEContext<Scheme::BFV>& context,
                                               bool store_in_gpu)
    {
        if (!context.context_generated_)
        {
            throw std::invalid_argument("HEContext is not generated!");
        }

        scheme_ = context.scheme_;
        key_type = context.keyswitching_type_;

        ring_size = context.n;
        Q_prime_size_ = context.Q_prime_size;
        Q_size_ = context.Q_size;

        storage_type_ =
            store_in_gpu ? storage_type::DEVICE : storage_type::HOST;

        switch (static_cast<int>(context.keyswitching_type_))
        {
            case 1: // KEYSWITCHING_METHOD_I
                switchkey_size_ = 2 * Q_size_ * Q_prime_size_ * ring_size;
                break;
            case 2: // KEYSWITCHING_METHOD_II
            {
                d_ = context.d;
                switchkey_size_ = 2 * d_ * Q_prime_size_ * ring_size;
            }
            break;
            case 3: // KEYSWITCHING_METHOD_III
                throw std::invalid_argument(
                    "Switchkey does not support KEYSWITCHING_METHOD_III");
                break;
            default:
                throw std::invalid_argument("Invalid Key Switching Type");
                break;
        }
    }

    void Switchkey<Scheme::BFV>::store_in_device(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            // pass
        }
        else
        {
            device_location_ = DeviceVector<Data64>(host_location_, stream);
            host_location_.resize(0);
            host_location_.shrink_to_fit();

            storage_type_ = storage_type::DEVICE;
        }
    }

    void Switchkey<Scheme::BFV>::store_in_host(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            host_location_ = HostVector<Data64>(switchkey_size_);
            cudaMemcpyAsync(host_location_.data(), device_location_.data(),
                            switchkey_size_ * sizeof(Data64),
                            cudaMemcpyDeviceToHost, stream);
            HEONGPU_CUDA_CHECK(cudaGetLastError());

            device_location_.resize(0, stream);

            storage_type_ = storage_type::HOST;
        }
        else
        {
            // pass
        }
    }

    Data64* Switchkey<Scheme::BFV>::data()
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            return device_location_.data();
        }
        else
        {
            return host_location_.data();
        }
    }

    void Switchkey<Scheme::BFV>::save(std::ostream& os) const
    {
        if (switch_key_generated_)
        {
            os.write((char*) &scheme_, sizeof(scheme_));

            os.write((char*) &key_type, sizeof(key_type));

            os.write((char*) &ring_size, sizeof(ring_size));

            os.write((char*) &Q_prime_size_, sizeof(Q_prime_size_));

            os.write((char*) &Q_size_, sizeof(Q_size_));

            os.write((char*) &d_, sizeof(d_));

            os.write((char*) &storage_type_, sizeof(storage_type_));

            os.write((char*) &switch_key_generated_,
                     sizeof(switch_key_generated_));

            os.write((char*) &switchkey_size_, sizeof(switchkey_size_));

            if (storage_type_ == storage_type::DEVICE)
            {
                HostVector<Data64> host_locations_temp(switchkey_size_);
                cudaMemcpy(host_locations_temp.data(), device_location_.data(),
                           switchkey_size_ * sizeof(Data64),
                           cudaMemcpyDeviceToHost);
                HEONGPU_CUDA_CHECK(cudaGetLastError());
                cudaDeviceSynchronize();

                os.write((char*) host_locations_temp.data(),
                         sizeof(Data64) * switchkey_size_);
            }
            else
            {
                os.write((char*) host_location_.data(),
                         sizeof(Data64) * switchkey_size_);
            }
        }
        else
        {
            throw std::runtime_error(
                "Switchkey is not generated so can not be serialized!");
        }
    }

    void Switchkey<Scheme::BFV>::load(std::istream& is)
    {
        if ((!switch_key_generated_))
        {
            is.read((char*) &scheme_, sizeof(scheme_));

            is.read((char*) &key_type, sizeof(key_type));

            is.read((char*) &ring_size, sizeof(ring_size));

            is.read((char*) &Q_prime_size_, sizeof(Q_prime_size_));

            is.read((char*) &Q_size_, sizeof(Q_size_));

            is.read((char*) &d_, sizeof(d_));

            is.read((char*) &storage_type_, sizeof(storage_type_));

            is.read((char*) &switch_key_generated_,
                    sizeof(switch_key_generated_));

            is.read((char*) &switchkey_size_, sizeof(switchkey_size_));

            storage_type_ = storage_type::DEVICE;
            switch_key_generated_ = true;

            HostVector<Data64> host_locations_temp(switchkey_size_);
            is.read((char*) host_locations_temp.data(),
                    sizeof(Data64) * switchkey_size_);

            cudaMemcpy(device_location_.data(), host_locations_temp.data(),
                       switchkey_size_ * sizeof(Data64),
                       cudaMemcpyHostToDevice);
            HEONGPU_CUDA_CHECK(cudaGetLastError());
            cudaDeviceSynchronize();
        }
        else
        {
            throw std::runtime_error("Switchkey has been already exist!");
        }
    }

    int Switchkey<Scheme::BFV>::memory_size()
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            return device_location_.size();
        }
        else
        {
            return host_location_.size();
        }
    }

    void Switchkey<Scheme::BFV>::memory_clear(cudaStream_t stream)
    {
        if (device_location_.size() > 0)
        {
            device_location_.resize(0, stream);
            device_location_.shrink_to_fit(stream);
        }

        if (host_location_.size() > 0)
        {
            host_location_.resize(0);
            host_location_.shrink_to_fit();
        }
    }

    void
    Switchkey<Scheme::BFV>::memory_set(DeviceVector<Data64>&& new_device_vector)
    {
        storage_type_ = storage_type::DEVICE;
        device_location_ = std::move(new_device_vector);

        if (host_location_.size() > 0)
        {
            host_location_.resize(0);
            host_location_.shrink_to_fit();
        }
    }

    void Switchkey<Scheme::BFV>::copy_to_device(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            // pass
        }
        else
        {
            if (memory_size() == 0)
            {
                // pass
            }
            else
            {
                device_location_ = DeviceVector<Data64>(host_location_, stream);
            }

            storage_type_ = storage_type::DEVICE;
        }
    }

    void Switchkey<Scheme::BFV>::remove_from_device(cudaStream_t stream)
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            device_location_.resize(0, stream);
            device_location_.shrink_to_fit(stream);

            storage_type_ = storage_type::HOST;
        }
        else
        {
            // pass
        }
    }

    void Switchkey<Scheme::BFV>::remove_from_host()
    {
        if (storage_type_ == storage_type::DEVICE)
        {
            // pass
        }
        else
        {
            host_location_.resize(0);
            host_location_.shrink_to_fit();

            storage_type_ = storage_type::DEVICE;
        }
    }

} // namespace heongpu