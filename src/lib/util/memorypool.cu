// Copyright 2024-2026 Alişah Özcan
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Developer: Alişah Özcan

#include <heongpu/util/memorypool.cuh>

namespace heongpu
{
    //helper
    struct ScopedDevice {
        int prev_device;
        ScopedDevice(int new_device) {
            HEONGPU_CUDA_CHECK(cudaGetDevice(&prev_device));
            if (prev_device != new_device) {
                HEONGPU_CUDA_CHECK(cudaSetDevice(new_device));
            }
        }
        ~ScopedDevice() {
            // Restore previous device to prevent side effects in the caller
            cudaSetDevice(prev_device);
        }
    };
    // -------------------------------------------------

    std::shared_ptr<MemoryPool::HostResource> MemoryPool::host_base_ = nullptr;
    std::shared_ptr<MemoryPool::HostPoolResource> MemoryPool::host_pool_ =
        nullptr;
    std::shared_ptr<MemoryPool::HostStatsAdaptor>
        MemoryPool::host_stats_adaptor_ = nullptr;

    std::vector<int> MemoryPool::active_devices = {0};
    std::unordered_map<int, std::shared_ptr<MemoryPool::DeviceResource>> MemoryPool::device_bases_ = {};
    std::unordered_map<int, std::shared_ptr<MemoryPool::DevicePoolResource>> MemoryPool::device_pools_ = {};
    std::unordered_map<int, std::shared_ptr<MemoryPool::DeviceStatsAdaptor>> MemoryPool::device_stats_adaptors_ = {};
    bool MemoryPool::initialized_ = false;
    std::mutex MemoryPool::mutex_;

    MemoryPoolConfig MemoryPoolConfig::Defaults()
    {
        MemoryPoolConfig config;
        config.initial_device_fraction = initial_device_memorypool_size;
        config.max_device_fraction = max_device_memorypool_size;
        config.max_host_fraction = max_host_memorypool_size;
        config.use_memory_pool = true; // Ensure this defaults to what you expect
        return config;
    }

    MemoryPool& MemoryPool::instance()
    {
        // Initialize CUDA runtime before the singleton is constructed so that
        // teardown order stays correct at process exit.
        cudaFree(nullptr);
        HEONGPU_CUDA_CHECK(cudaGetLastError());

        static MemoryPool instance;
        return instance;
    }

    void MemoryPool::ensure_base_resources(int device_id)
    {
        // No lock here; caller must hold lock if needed.
        if (!host_base_)
        {
            host_base_ = std::make_shared<HostResource>();
        }
        
        if (device_bases_.find(device_id) == device_bases_.end()) {
            ScopedDevice sd(device_id); // Safe context switch
            device_bases_[device_id] = std::make_shared<DeviceResource>();
        }
    }

    size_t MemoryPool::get_host_avaliable_memory() const
    {
        struct sysinfo memInfo;
        sysinfo(&memInfo);
        size_t free_memory = memInfo.freeram * memInfo.mem_unit;
        return free_memory;
    }

    size_t MemoryPool::get_decive_avaliable_memory(int device_id) const
    {
        ScopedDevice sd(device_id); // Safe context switch
        size_t free_mem = 0;
        size_t total_mem = 0;
        cudaMemGetInfo(&free_mem, &total_mem);
        HEONGPU_CUDA_CHECK(cudaGetLastError());
        return free_mem; 
    }

    size_t MemoryPool::roundup_256(size_t size) const
    {
        return ((size + 255) / 256) * 256;
    }

    void MemoryPool::initialize()
    {
        initialize(MemoryPoolConfig::Defaults(), {0}); // Default to GPU 0
    }

    void MemoryPool::initialize(const MemoryPoolConfig& config, std::vector<int> target_devices)
    {
        std::lock_guard<std::mutex> guard(mutex_);
        if (!initialized_)
        {
            active_devices = target_devices;

            // 1. Ensure base resources exist for all targets
            for (int device_id : target_devices) {
                ensure_base_resources(device_id);
            }

            size_t total_host_memory = get_host_avaliable_memory();
            // Assuming homogeneous GPUs for pool sizing logic, grabbing stats from the first one
            size_t total_device_memory = get_decive_avaliable_memory(target_devices[0]); 

            auto normalize_fraction = [](float value, const char* label) -> float
            {
                if (value <= 0.0f) throw std::invalid_argument(std::string(label) + " must be > 0");
                if (value > 1.0f) {
                    if (value > 100.0f) throw std::invalid_argument(std::string(label) + " must be in (0,1] or (0,100]");
                    return value / 100.0f;
                }
                return value;
            };

            auto resolve_pool_size = [&](const std::optional<size_t>& bytes,
                    const std::optional<float>& fraction, size_t total_memory,
                    size_t default_bytes, float default_fraction,
                    const char* label) -> size_t
            {
                size_t resolved = 0;
                if (bytes.has_value()) {
                    if (*bytes == 0) throw std::invalid_argument(std::string(label) + " bytes must be > 0");
                    resolved = *bytes;
                } else if (fraction.has_value()) {
                    float f = normalize_fraction(*fraction, label);
                    resolved = static_cast<size_t>(total_memory * f);
                } else if (default_bytes != 0) {
                    resolved = default_bytes;
                } else {
                    float f = normalize_fraction(default_fraction, label);
                    resolved = static_cast<size_t>(total_memory * f);
                }

                if (resolved == 0) throw std::invalid_argument(std::string(label) + " resolved to 0 bytes");
                if (total_memory != 0 && resolved > total_memory) {
                    throw std::invalid_argument(std::string(label) + " exceeds available memory at initialization");
                }
                return roundup_256(resolved);
            };

            if (config.use_memory_pool)
            {
                // --- HOST POOL SETUP ---
                size_t initial_host_pool_size = 0;
                if (!config.initial_host_bytes.has_value() && !config.initial_host_fraction.has_value()) {
                    initial_host_pool_size = roundup_256(static_cast<size_t>(104857600));
                } else {
                    initial_host_pool_size = resolve_pool_size(
                        config.initial_host_bytes, config.initial_host_fraction,
                        total_host_memory, 0, initial_host_memorypool_size, "host initial pool size");
                }

                size_t max_host_pool_size = resolve_pool_size(
                    config.max_host_bytes, config.max_host_fraction,
                    total_host_memory, 0, max_host_memorypool_size, "host max pool size");

                if (max_host_pool_size < initial_host_pool_size) {
                    throw std::invalid_argument("host max pool size must be >= host initial pool size");
                }

                host_pool_ = std::make_shared<HostPoolResource>(
                    host_base_.get(), initial_host_pool_size, max_host_pool_size);
                host_stats_adaptor_ = std::make_shared<HostStatsAdaptor>(host_pool_.get());

                // --- DEVICE POOL SETUP ---
                size_t initial_device_pool_size = resolve_pool_size(
                    config.initial_device_bytes, config.initial_device_fraction,
                    total_device_memory, 0, initial_device_memorypool_size, "device initial pool size");
                size_t max_device_pool_size = resolve_pool_size(
                    config.max_device_bytes, config.max_device_fraction,
                    total_device_memory, 0, max_device_memorypool_size, "device max pool size");

                if (max_device_pool_size < initial_device_pool_size) {
                    throw std::invalid_argument("device max pool size must be >= device initial pool size");
                }

                for (int device_id : target_devices) {
                    ScopedDevice sd(device_id); // Safe context switch
                    
                    auto pool = std::make_shared<DevicePoolResource>(
                        device_bases_[device_id].get(), 
                        initial_device_pool_size,
                        max_device_pool_size
                    );
                    
                    device_pools_[device_id] = pool;
                    device_stats_adaptors_[device_id] = std::make_shared<DeviceStatsAdaptor>(pool.get());
                    
                    // CRITICAL FIX: Activate the pool for this device immediately
                    rmm::mr::set_current_device_resource(device_stats_adaptors_[device_id].get());
                }
            }

            initialized_ = true;
        }
    }

    void MemoryPool::use_memory_pool(bool use, const std::vector<int>& target_devices)
    {
        std::lock_guard<std::mutex> guard(mutex_);
        for (int device_id : target_devices)
        {
            ScopedDevice sd(device_id); // Safe context switch

            if (use && device_stats_adaptors_.count(device_id))
            {
                rmm::mr::set_current_device_resource(device_stats_adaptors_[device_id].get());
            }
            else
            {
                ensure_base_resources(device_id);
                rmm::mr::set_current_device_resource(device_bases_[device_id].get());
            }
        }
    }

    void* MemoryPool::allocate(size_t size, cudaStream_t stream)
    {
        // Allocation uses the CURRENT device's resource. 
        // We rely on RMM to handle the lookup based on the active CUDA device.
        std::lock_guard<std::mutex> guard(mutex_);
        return rmm::mr::get_current_device_resource()->allocate(size, stream);
    }

    void MemoryPool::deallocate(void* ptr, size_t size, cudaStream_t stream)
    {
        std::lock_guard<std::mutex> guard(mutex_);
        rmm::mr::get_current_device_resource()->deallocate(ptr, size, stream);
    }

    rmm::mr::device_memory_resource* MemoryPool::get_device_resource(int device_id) const
    {
        std::lock_guard<std::mutex> guard(mutex_);
        if (device_stats_adaptors_.find(device_id) != device_stats_adaptors_.end())
        {
            return device_stats_adaptors_.at(device_id).get();
        }
        
        // Use const_cast safely to ensure base resources exist
        const_cast<MemoryPool*>(this)->ensure_base_resources(device_id);
        return device_bases_.at(device_id).get();
    }

    MemoryPool::HostStatsAdaptor* MemoryPool::get_host_resource() const
    {
        std::lock_guard<std::mutex> guard(mutex_);
        return host_stats_adaptor_.get();
    }

    void* MemoryPool::host_allocate(size_t size)
    {
        std::lock_guard<std::mutex> guard(mutex_);
        if (host_pool_)
        {
            return host_pool_->allocate(size);
        }

        ensure_base_resources(0); 
        return host_base_->allocate(size);
    }

    void MemoryPool::host_deallocate(void* ptr, size_t size)
    {
        std::lock_guard<std::mutex> guard(mutex_);
        if (host_pool_)
        {
            host_pool_->deallocate(ptr, size);
            return;
        }
        ensure_base_resources(0);
        host_base_->deallocate(ptr, size);
    }

    void MemoryPool::print_memory_pool_status(int device_id) const
    {
        std::lock_guard<std::mutex> guard(mutex_);
        if (device_stats_adaptors_.count(device_id) && device_pools_.count(device_id) && host_stats_adaptor_ &&
            host_pool_)
        {
            auto device_status = device_stats_adaptors_.at(device_id)->get_bytes_counter();
            const auto device_total = device_pools_.at(device_id)->pool_size();
            const auto device_used = device_status.value;
            const auto device_free = device_total - device_used;

            auto host_status = host_stats_adaptor_->get_bytes_counter();
            const auto host_total = host_pool_->pool_size();
            const auto host_used = host_status.value;
            const auto host_free = host_total - host_used;

            std::cout << "[HEonGPU] Memory Pool Status (Device " << device_id << ")" << std::endl;
            std::cout << "  Device Pool:" << std::endl;
            std::cout << "    Total     : " << device_total << " bytes" << std::endl;
            std::cout << "    Used      : " << device_used << " bytes" << std::endl;
            std::cout << "    Free      : " << device_free << " bytes" << std::endl;
            std::cout << "  Host Pool:" << std::endl;
            std::cout << "    Total     : " << host_total << " bytes" << std::endl;
            std::cout << "    Used      : " << host_used << " bytes" << std::endl;
            std::cout << "    Free      : " << host_free << " bytes" << std::endl;
        }
        else
        {
            std::cout << "[HEonGPU] Memory pool is not initialized or is disabled for device " << device_id << std::endl;
        }
    }

    size_t MemoryPool::get_current_device_pool_memory_usage(int device_id) const
    {
        std::lock_guard<std::mutex> guard(mutex_);
        if (!device_stats_adaptors_.count(device_id)) return 0;
        auto device_status = device_stats_adaptors_.at(device_id)->get_bytes_counter();
        return device_status.value;
    }

    size_t MemoryPool::get_free_device_pool_memory(int device_id) const
    {
        std::lock_guard<std::mutex> guard(mutex_);
        if (!device_stats_adaptors_.count(device_id) || !device_pools_.count(device_id)) return 0;
        auto device_status = device_stats_adaptors_.at(device_id)->get_bytes_counter();
        return device_pools_.at(device_id)->pool_size() - device_status.value;
    }

    size_t MemoryPool::get_current_host_pool_memory_usage() const
    {
        std::lock_guard<std::mutex> guard(mutex_);
        if (!host_stats_adaptor_) return 0;
        auto host_status = host_stats_adaptor_->get_bytes_counter();
        return host_status.value;
    }

    size_t MemoryPool::get_free_host_pool_memory() const
    {
        std::lock_guard<std::mutex> guard(mutex_);
        if (!host_stats_adaptor_ || !host_pool_) return 0;
        auto host_status = host_stats_adaptor_->get_bytes_counter();
        return host_pool_->pool_size() - host_status.value;
    }

    MemoryPool::~MemoryPool()
    {
        clean_pool();
    }

    MemoryPool::MemoryPool() = default;

    void MemoryPool::clean_pool()
    {
        std::lock_guard<std::mutex> guard(mutex_);
        // Clean up resources. Note: Resetting global RMM resource is tricky if threads are active.
        // Usually, we set it to nullptr or let it be.
        rmm::mr::set_current_device_resource(nullptr);
        
        host_stats_adaptor_.reset();
        host_pool_.reset();
        host_base_.reset();
        
        device_stats_adaptors_.clear();
        device_pools_.clear();
        device_bases_.clear();
        
        initialized_ = false;
    }

} // namespace heongpu