# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

if (onnxruntime_MINIMAL_BUILD AND NOT onnxruntime_EXTENDED_MINIMAL_BUILD)
  message(FATAL_ERROR "CoreML EP can not be used in a basic minimal build. Please build with '--minimal_build extended'")
endif()

add_compile_definitions(USE_COREML=1)

# Compile CoreML proto definition to ${CMAKE_CURRENT_BINARY_DIR}/coreml_proto
set(COREML_PROTO_ROOT ${coremltools_SOURCE_DIR}/mlmodel/format)
file(GLOB coreml_proto_srcs "${COREML_PROTO_ROOT}/*.proto")

onnxruntime_add_static_library(coreml_proto ${coreml_proto_srcs})
target_include_directories(coreml_proto
                           PUBLIC $<TARGET_PROPERTY:${PROTOBUF_LIB},INTERFACE_INCLUDE_DIRECTORIES>
                           "${CMAKE_CURRENT_BINARY_DIR}")
target_compile_definitions(coreml_proto
                           PUBLIC $<TARGET_PROPERTY:${PROTOBUF_LIB},INTERFACE_COMPILE_DEFINITIONS>)
set_target_properties(coreml_proto PROPERTIES COMPILE_FLAGS "-fvisibility=hidden")
set_target_properties(coreml_proto PROPERTIES COMPILE_FLAGS "-fvisibility-inlines-hidden")
set(_src_sub_dir "coreml_proto/")

onnxruntime_protobuf_generate(
  APPEND_PATH
  GEN_SRC_SUB_DIR ${_src_sub_dir}
  IMPORT_DIRS ${COREML_PROTO_ROOT}
  TARGET coreml_proto
)

if (NOT onnxruntime_BUILD_SHARED_LIB)
  install(TARGETS coreml_proto
          ARCHIVE   DESTINATION ${CMAKE_INSTALL_LIBDIR}
          LIBRARY   DESTINATION ${CMAKE_INSTALL_LIBDIR}
          RUNTIME   DESTINATION ${CMAKE_INSTALL_BINDIR}
          FRAMEWORK DESTINATION ${CMAKE_INSTALL_BINDIR}
  )
endif()

# Add the .proto and generated .cc/.h files to the External/coreml_proto folder in Visual Studio.
# Separate source_group for each as the .proto files are in the repo and the .cc/.h files are generated in the build
# output directory.
set_target_properties(coreml_proto PROPERTIES FOLDER "External")
source_group(TREE ${COREML_PROTO_ROOT} PREFIX coreml_proto FILES ${coreml_proto_srcs})

# filter to the generated .cc/.h files
get_target_property(coreml_proto_generated_srcs coreml_proto SOURCES)
list(FILTER coreml_proto_generated_srcs INCLUDE REGEX "\.pb\.(h|cc)$")
source_group(TREE ${CMAKE_CURRENT_BINARY_DIR} PREFIX coreml_proto_generated FILES ${coreml_proto_generated_srcs})

# These are shared utils,
# TODO, move this to a separated lib when used by EPs other than NNAPI and CoreML
file(GLOB_RECURSE onnxruntime_providers_shared_utils_cc_srcs CONFIGURE_DEPENDS
  "${ONNXRUNTIME_ROOT}/core/providers/shared/utils/utils.h"
  "${ONNXRUNTIME_ROOT}/core/providers/shared/utils/utils.cc"
)

file(GLOB
  onnxruntime_providers_coreml_cc_srcs_top CONFIGURE_DEPENDS
  "${ONNXRUNTIME_ROOT}/core/providers/coreml/*.h"
  "${ONNXRUNTIME_ROOT}/core/providers/coreml/*.cc"
)

# Add builder source code
file(GLOB_RECURSE
  onnxruntime_providers_coreml_cc_srcs_nested CONFIGURE_DEPENDS
  "${ONNXRUNTIME_ROOT}/core/providers/coreml/builders/*.h"
  "${ONNXRUNTIME_ROOT}/core/providers/coreml/builders/*.cc"
)
if (NOT CMAKE_SYSTEM_NAME STREQUAL "Darwin" AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  list(REMOVE_ITEM onnxruntime_providers_coreml_cc_srcs_nested
  "${ONNXRUNTIME_ROOT}/core/providers/coreml/builders/model_builder.h"
  "${ONNXRUNTIME_ROOT}/core/providers/coreml/builders/model_builder.cc"
  )
endif()

# Add CoreML objective c++ source code
if (CMAKE_SYSTEM_NAME STREQUAL "Darwin" OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
  file(GLOB
    onnxruntime_providers_coreml_objcc_srcs CONFIGURE_DEPENDS
    "${ONNXRUNTIME_ROOT}/core/providers/coreml/model/model.h"
    "${ONNXRUNTIME_ROOT}/core/providers/coreml/model/model.mm"
    "${ONNXRUNTIME_ROOT}/core/providers/coreml/model/host_utils.h"
    "${ONNXRUNTIME_ROOT}/core/providers/coreml/model/host_utils.mm"
  )
endif()

set(onnxruntime_providers_coreml_cc_srcs
  ${onnxruntime_providers_coreml_cc_srcs_top}
  ${onnxruntime_providers_coreml_cc_srcs_nested}
  ${onnxruntime_providers_shared_utils_cc_srcs}
)

source_group(TREE ${ONNXRUNTIME_ROOT}/core FILES ${onnxruntime_providers_coreml_cc_srcs})
onnxruntime_add_static_library(onnxruntime_providers_coreml
  ${onnxruntime_providers_coreml_cc_srcs} ${onnxruntime_providers_coreml_objcc_srcs}
)
onnxruntime_add_include_to_target(onnxruntime_providers_coreml
  onnxruntime_common onnxruntime_framework onnx onnx_proto ${PROTOBUF_LIB}  flatbuffers::flatbuffers Boost::mp11 safeint_interface
)
if (CMAKE_SYSTEM_NAME STREQUAL "Darwin" OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
  onnxruntime_add_include_to_target(onnxruntime_providers_coreml coreml_proto)
  target_link_libraries(onnxruntime_providers_coreml PRIVATE coreml_proto "-framework Foundation" "-framework CoreML")
  add_dependencies(onnxruntime_providers_coreml coreml_proto)
endif()
add_dependencies(onnxruntime_providers_coreml ${onnxruntime_EXTERNAL_DEPENDENCIES})

set_target_properties(onnxruntime_providers_coreml PROPERTIES CXX_STANDARD_REQUIRED ON)
set_target_properties(onnxruntime_providers_coreml PROPERTIES FOLDER "ONNXRuntime")
target_include_directories(onnxruntime_providers_coreml PRIVATE ${ONNXRUNTIME_ROOT} ${coreml_INCLUDE_DIRS})
set_target_properties(onnxruntime_providers_coreml PROPERTIES LINKER_LANGUAGE CXX)

if (NOT onnxruntime_BUILD_SHARED_LIB)
  install(TARGETS onnxruntime_providers_coreml
          ARCHIVE   DESTINATION ${CMAKE_INSTALL_LIBDIR}
          LIBRARY   DESTINATION ${CMAKE_INSTALL_LIBDIR}
          RUNTIME   DESTINATION ${CMAKE_INSTALL_BINDIR}
          FRAMEWORK DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()
