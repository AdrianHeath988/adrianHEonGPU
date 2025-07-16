#include "memorypool.cuh"
#include <iostream>
#include "shutdown_c_api.h"


extern "C" void heongpu_shutdown() {
    std::cout << "[HEonGPU] Initiating manual shutdown..." << std::endl;

    MemoryPool::instance().clean_pool();
    
    std::cout << "[HEonGPU] Manual shutdown complete." << std::endl;
}