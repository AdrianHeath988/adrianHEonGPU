// Copyright 2024-2026 Alişah Özcan
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Developer: Alişah Özcan

#ifndef HEONGPU_MEMORY_POOL_H
#define HEONGPU_MEMORY_POOL_H

#include <mutex>
#include <memory>
#include <vector>
#include <optional>
#include <sys/sysinfo.h>

#include "gpuntt/common/common.cuh"
#include "gpuntt/common/nttparameters.cuh"
#include <heongpu/kernel/defines.h>
#include <heongpu/util/util.cuh>

#include <thrust/host_vector.h>
#include <rmm/device_buffer.hpp>
#include <rmm/device_uvector.hpp>

#include <rmm/mr/host/pinned_memory_resource.hpp>
#include <rmm/mr/host/host_memory_resource.hpp>
#include <rmm/mr/device/cuda_memory_resource.hpp>
#include <rmm/mr/device/pool_memory_resource.hpp>
#include <rmm/mr/device/statistics_resource_adaptor.hpp>
#include <rmm/mr/device/detail/stream_ordered_memory_resource.hpp>
#include <rmm/mr/device/logging_resource_adaptor.hpp>

// --------------------- //
// Author: Alisah Ozcan
// --------------------- //

namespace heongpu
{
    struct MemoryPoolConfig
    {
        // Fractions accept either 0.0-1.0 (ratio) or 0-100 (percentage).
        std::optional<float> initial_device_fraction;
        std::optional<float> max_device_fraction;
        std::optional<size_t> initial_device_bytes;
        std::optional<size_t> max_device_bytes;

        std::optional<float> initial_host_fraction;
        std::optional<float> max_host_fraction;
        std::optional<size_t> initial_host_bytes;
        std::optional<size_t> max_host_bytes;

        bool use_memory_pool = true;

        static MemoryPoolConfig Defaults();
    };

    class MemoryPool
    {
        using DeviceResource = rmm::mr::cuda_memory_resource;
        using DevicePoolResource =
            rmm::mr::pool_memory_resource<DeviceResource>;
        using DeviceStatsAdaptor = rmm::mr::statistics_resource_adaptor<
            rmm::mr::device_memory_resource>;

        using HostResource = rmm::mr::pinned_memory_resource;
        using HostPoolResource = rmm::mr::pool_memory_resource<HostResource>;
        using HostStatsAdaptor =
            rmm::mr::statistics_resource_adaptor<HostPoolResource>;

      public:
        static MemoryPool& instance();

        void initialize();
        void initialize(const MemoryPoolConfig& config){
            std::vector<int> target_devices;
            int device_count = 0;
            cudaGetDeviceCount(&device_count);
            for (int i = 0; i < device_count; ++i) {
                target_devices.push_back(i);
            }
            return initialize(config, target_devices);
        }
        void initialize(const MemoryPoolConfig& config, std::vector<int> target_devices);
        // for device
        void use_memory_pool(bool use){
            use_memory_pool(use, active_devices);
        }
        void use_memory_pool(bool use, const std::vector<int>& target_devices);
        

        // for device
        void* allocate(size_t size, cudaStream_t stream = cudaStreamDefault);
        void deallocate(void* ptr, size_t size,
                        cudaStream_t stream = cudaStreamDefault);

        rmm::mr::device_memory_resource* get_device_resource() const{
            int current_device;
            cudaGetDevice(&current_device); // Get the actual active GPU
            return get_device_resource(current_device);
        }
        rmm::mr::device_memory_resource* get_device_resource(int device_id) const;
        HostStatsAdaptor* get_host_resource() const;

        void* host_allocate(size_t size);
        void host_deallocate(void* ptr, size_t size);

        void print_memory_pool_status() const{
            print_memory_pool_status(active_devices[0]); // Assuming the first active device for default
        }
        void print_memory_pool_status(int device_id) const;
        size_t get_current_device_pool_memory_usage() const{
            return get_current_device_pool_memory_usage(active_devices[0]); // Assuming the first active device for default
        }
        size_t get_current_device_pool_memory_usage(int device_id) const;

        size_t get_free_device_pool_memory() const{
            return get_free_device_pool_memory(active_devices[0]); // Assuming the first active device for default
        }
        size_t get_free_device_pool_memory(int device_id) const;

        size_t get_current_host_pool_memory_usage() const;
        size_t get_free_host_pool_memory() const;

        ~MemoryPool();

      private:
        MemoryPool();
        MemoryPool(const MemoryPool&) = delete;
        MemoryPool& operator=(const MemoryPool&) = delete;

        void clean_pool();
        void ensure_base_resources(int device_id);
        size_t get_host_avaliable_memory() const;
        size_t get_decive_avaliable_memory(int device_id) const;
        size_t roundup_256(size_t size) const;

        static std::shared_ptr<HostResource> host_base_;
        static std::shared_ptr<HostPoolResource> host_pool_;
        static std::shared_ptr<HostStatsAdaptor> host_stats_adaptor_;

        //for multi-gpu
        // static std::shared_ptr<DeviceResource> device_base_;
        static std::unordered_map<int, std::shared_ptr<DeviceResource>> device_bases_;
        // static std::shared_ptr<DevicePoolResource> device_pool_;
        
        static std::unordered_map<int, std::shared_ptr<DevicePoolResource>> device_pools_;
        static std::unordered_map<int, std::shared_ptr<DeviceStatsAdaptor>> device_stats_adaptors_;
        //static std::shared_ptr<DeviceStatsAdaptor> device_stats_adaptor_;

        static std::vector<int> active_devices;

        static bool initialized_;
        static std::mutex mutex_;
    };

    template <typename T> struct rmm_pinned_allocator
    {
        using value_type = T;
        using HostResource = rmm::mr::pinned_memory_resource;
        using HostPoolResource = rmm::mr::pool_memory_resource<HostResource>;

        rmm_pinned_allocator() = default;

        T* allocate(std::size_t n)
        {
            return static_cast<T*>(
                MemoryPool::instance().host_allocate(n * sizeof(T)));
        }

        void deallocate(T* p, std::size_t n)
        {
            MemoryPool::instance().host_deallocate(p, n * sizeof(T));
        }

        bool operator==(const rmm_pinned_allocator& other) const
        {
            return true;
        }
        bool operator!=(const rmm_pinned_allocator& other) const
        {
            return !(*this == other);
        }
    };

} // namespace heongpu

#endif // HEONGPU_MEMORY_POOL_H
