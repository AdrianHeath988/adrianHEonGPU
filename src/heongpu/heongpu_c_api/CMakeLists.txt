cmake_minimum_required(VERSION 3.26) # Match HEonGPU's requirement

project(heongpu_c_api LANGUAGES CXX CUDA)

# Find an installed HEonGPU package or use it as a subdirectory.
# For this example, we assume HEonGPU::heongpu target is available from parent scope,
# which means the main libheongpu.so has been defined.

# Include directories - HEonGPU headers and this directory for heongpu_c_api.h
# The main HEonGPU library should already make its include directories available.
# We need the include directory of the main heongpu library.
# Assuming HEonGPU::heongpu is an INTERFACE library or correctly sets up its
# include directories for targets linking to it. If not, you might need:
# target_include_directories(heongpu_c_api PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
# And ensure the main HEonGPU include path is also available.
# Typically, if HEonGPU::heongpu is a target from add_subdirectory or find_package,
# its include paths should propagate.

# For CUDA in the C API (if your C API wrappers need to call CUDA kernels directly,
# which is unlikely for simple wrappers, but good to be aware of).
# HEonGPU itself uses CUDA, so CUDA toolkit should be found by the parent project.
find_package(CUDAToolkit REQUIRED)

target_link_libraries(heongpu PUBLIC 
    ntt
    fft
    rngongpu
    gmp
    rmm
    CUDA::curand
    ZLIB::ZLIB
)

add_library(heongpu_c_api SHARED 
    ciphertext_c_api.cu
    ciphertext_c_api.h
    context_c_api.cu
    context_c_api.h
    decryptor_c_api.cu
    decryptor_c_api.h
    encoder_c_api.cu
    encoder_c_api.h
    evaluationkey_c_api.cu
    evaluationkey_c_api.h
    keygenerator_c_api.cu
    keygenerator_c_api.h
    operator_c_api.cu
    operator_c_api.h
    plaintext_c_api.cu
    plaintext_c_api.h
    publickey_c_api.cu
    publickey_c_api.h
    secretkey_c_api.cu
    secretkey_c_api.h
    serializer_c_api.cu
    serializer_c_api.h
    shutdown_c_api.cu
    shutdown_c_api.h
)

# Link against the main HEonGPU library.
# The target HEonGPU::heongpu should be provided by the main HEonGPU CMake build.
# The README mentions `target_link_libraries(<your-target> ... HEonGPU::heongpu CUDA::cudart)`
# when using HEonGPU in a downstream project.
target_link_libraries(heongpu_c_api PRIVATE HEonGPU::heongpu CUDA::cudart)

# Set properties for CUDA separable compilation if needed, though likely inherited
# or not strictly necessary if the C API cpp file doesn't have .cu kernels itself.
set_target_properties(heongpu_c_api PROPERTIES CUDA_SEPARABLE_COMPILATION ON)

install(TARGETS heongpu_c_api
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)
install(FILES heongpu_c_api.h DESTINATION include)