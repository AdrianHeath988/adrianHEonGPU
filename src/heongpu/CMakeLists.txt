# Copyright 2024-2025 Alişah Özcan
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Developer: Alişah Özcan

file(GLOB_RECURSE LIB_SOURCE_FILES
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    CONFIGURE_DEPENDS
    lib/host/*.cu
    lib/host/bfv/*.cu
    lib/host/ckks/*.cu
    lib/host/tfhe/*.cu
    lib/kernel/*.cu
    lib/util/*.cu
    lib/util/*.cpp
)

add_library(heongpu STATIC ${LIB_SOURCE_FILES})

set_target_properties(heongpu PROPERTIES
  VERSION ${PROJECT_VERSION}
  SOVERSION 1
  OUTPUT_NAME "heongpu-${PROJECT_VERSION}"
)

target_include_directories(
    heongpu
    PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/host>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/kernel>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/util>
    $<INSTALL_INTERFACE:include/HEonGPU-${PROJECT_VERSION}>
)

target_link_libraries(heongpu PUBLIC 
    ntt
    fft
    rngongpu
    gmp
    rmm
    CUDA::curand
    ZLIB::ZLIB
)

set_target_properties(heongpu PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON
        POSITION_INDEPENDENT_CODE ON
        CMAKE_CUDA_RESOLVE_DEVICE_SYMBOLS ON
        CUDA_RUNTIME_LIBRARY Static
        CUDA_ARCHITECTURES ${CMAKE_CUDA_ARCHITECTURES}
)

add_library(HEonGPU::heongpu ALIAS heongpu)
add_library(heongpu_c_api SHARED
    heongpu_c_api/ciphertext_c_api.cu
    heongpu_c_api/ciphertext_c_api.h
    heongpu_c_api/context_c_api.cu
    heongpu_c_api/context_c_api.h
    heongpu_c_api/decryptor_c_api.cu
    heongpu_c_api/decryptor_c_api.h
    heongpu_c_api/encoder_c_api.cu
    heongpu_c_api/encoder_c_api.h
    heongpu_c_api/encryptor_c_api.cu
    heongpu_c_api/encryptor_c_api.h
    heongpu_c_api/evaluationkey_c_api.cu
    heongpu_c_api/evaluationkey_c_api.h
    heongpu_c_api/keygenerator_c_api.cu
    heongpu_c_api/keygenerator_c_api.h
    heongpu_c_api/operator_c_api.cu
    heongpu_c_api/operator_c_api.h
    heongpu_c_api/plaintext_c_api.cu
    heongpu_c_api/plaintext_c_api.h
    heongpu_c_api/publickey_c_api.cu
    heongpu_c_api/publickey_c_api.h
    heongpu_c_api/secretkey_c_api.cu
    heongpu_c_api/secretkey_c_api.h
    heongpu_c_api/serializer_c_api.cu
    heongpu_c_api/serializer_c_api.h
    heongpu_c_api/shutdown_c_api.h
    heongpu_c_api/shutdown_c_api.cu
)
target_link_libraries(heongpu_c_api PUBLIC # Or PRIVATE, depending on usage
    HEonGPU::heongpu # Links against the static heongpu library
    CUDA::cudart
)

set_target_properties(heongpu_c_api PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    CUDA_SEPARABLE_COMPILATION ON
    OUTPUT_NAME "heongpu_c_api-${PROJECT_VERSION}"
)
set_property(TARGET heongpu_c_api PROPERTY VERSION ${PROJECT_VERSION})
set_property(TARGET heongpu_c_api PROPERTY SOVERSION 1)

# Installation for C API library and header
install(TARGETS heongpu_c_api
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib # For Windows DLL import libraries
    RUNTIME DESTINATION bin # For Windows DLLs
)
install(FILES 
    heongpu_c_api/ciphertext_c_api.h
    heongpu_c_api/context_c_api.h
    heongpu_c_api/decryptor_c_api.h
    heongpu_c_api/encoder_c_api.h
    heongpu_c_api/encryptor_c_api.h
    heongpu_c_api/evaluationkey_c_api.h
    heongpu_c_api/keygenerator_c_api.h
    heongpu_c_api/operator_c_api.h
    heongpu_c_api/plaintext_c_api.h
    heongpu_c_api/publickey_c_api.h
    heongpu_c_api/secretkey_c_api.h
    heongpu_c_api/serializer_c_api.h
    heongpu_c_api/shutdown_c_api.h
DESTINATION include) 


install(TARGETS heongpu
  EXPORT ${HEonGPU_TARGETS_EXPORT_NAME}
  RUNTIME DESTINATION ${RUNTIME_DESTINATION}
  LIBRARY DESTINATION ${LIBRARY_DESTINATION}
  ARCHIVE DESTINATION ${ARCHIVE_DESTINATION}
)

install(
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/host/
  DESTINATION ${INCLUDES_INSTALL_DIR}
  FILES_MATCHING
    PATTERN "*.h"
    PATTERN "*.cuh"
)

install(
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/kernel/
  DESTINATION ${INCLUDES_INSTALL_DIR}
  FILES_MATCHING
    PATTERN "*.h"
    PATTERN "*.cuh"
)

install(
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/util/
  DESTINATION ${INCLUDES_INSTALL_DIR}
  FILES_MATCHING
    PATTERN "*.h"
    PATTERN "*.cuh"
)