#!/bin/bash
# Build whisper.cpp for FFmpeg integration
# Based on https://github.com/ggml-org/whisper.cpp

set -e
echo -e "\n[Build whisper.cpp]"

SRC_DIR=$(pwd)/whisper.cpp
BUILD_DIR=build/whisper.cpp
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Note: This script is only called for amd64/x64 builds (see build.sh)
# ARM64 is not supported due to MSVC/clang-cl compatibility issues

# Build whisper.cpp with MSVC
# - Static library for FFmpeg integration
# - OpenCL support (already built)
# - Vulkan support (if available)
# - Disable tests, examples, server
# - Use internal ggml (not system-installed)
# - Enable SIMD optimizations for x64

WHISPER_CMAKE_ARGS=(
    -G "NMake Makefiles"
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW
    -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded
    -DBUILD_SHARED_LIBS=OFF
    -DWHISPER_BUILD_TESTS=OFF
    -DWHISPER_BUILD_EXAMPLES=OFF
    -DWHISPER_BUILD_SERVER=OFF
    -DWHISPER_USE_SYSTEM_GGML=OFF
)

# GGML options for x64
GGML_ARGS=(
    -DGGML_CCACHE=OFF
    -DGGML_OPENCL=ON
    -DGGML_NATIVE=OFF
    # SIMD optimizations for x86_64
    -DGGML_SSE42=ON
    -DGGML_AVX=ON
    -DGGML_F16C=ON
    -DGGML_AVX2=ON
    -DGGML_BMI2=ON
    -DGGML_FMA=ON
)

# Vulkan support if available
if [ -n "$VULKAN_SDK" ] && [ -d "$VULKAN_SDK" ]; then
    echo "Vulkan SDK found, enabling Vulkan support in whisper.cpp"
    GGML_ARGS+=(-DGGML_VULKAN=ON)
else
    GGML_ARGS+=(-DGGML_VULKAN=OFF)
fi

# Run CMake
cmake "$SRC_DIR" "${WHISPER_CMAKE_ARGS[@]}" "${GGML_ARGS[@]}"

# Build
cmake --build . --config Release -j$(nproc)

# Install
cmake --install . --config Release

# Create pkg-config file for FFmpeg
mkdir -p "$INSTALL_PREFIX/lib/pkgconfig"

# whisper.cpp uses multiple ggml libraries that need to be linked in correct order
GGML_LIBS="-lggml -lggml-base -lggml-cpu -lggml-opencl"

# Add Vulkan if enabled (x64 only)
if [ -n "$VULKAN_SDK" ] && [ -d "$VULKAN_SDK" ]; then
    GGML_LIBS="$GGML_LIBS -lggml-vulkan"
    # Add Vulkan library path directly instead of pkg-config (vulkan.pc not always available)
    # Convert path using cygpath for proper Windows path handling (same as build-ffmpeg.sh)
    VULKAN_PATH_SHORT=$(cygpath -sw "$VULKAN_SDK")
    VULKAN_PATH_FIXED=$(cygpath -m "$VULKAN_PATH_SHORT")
    VULKAN_LIBS="-L\"${VULKAN_PATH_FIXED}/Lib\" -lvulkan-1"
else
    VULKAN_LIBS=""
fi

cat > "$INSTALL_PREFIX/lib/pkgconfig/whisper.pc" << EOF
prefix=$INSTALL_PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: whisper
Description: OpenAI Whisper speech recognition library
Version: 1.7.6
Cflags: -I\${includedir}
Libs: -L\${libdir} -lwhisper $VULKAN_LIBS
Libs.private: $GGML_LIBS -lOpenCL
EOF

echo "whisper.cpp built successfully"
