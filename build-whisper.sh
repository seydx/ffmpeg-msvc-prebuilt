#!/bin/bash
# Build whisper.cpp for FFmpeg integration
# Based on https://github.com/ggml-org/whisper.cpp

set -e
echo -e "\n[Build whisper.cpp]"

SRC_DIR=$(pwd)/whisper.cpp
BUILD_DIR=build/whisper.cpp
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

case $BUILD_ARCH in
amd64)
    ARCH=x64
    ;;
arm64)
    ARCH=ARM64
    ;;
*)
    echo "Unsupported architecture: $BUILD_ARCH"
    exit 1
    ;;
esac

# Build whisper.cpp with MSVC
# - Static library for FFmpeg integration
# - OpenCL support (already built)
# - Vulkan support (if available)
# - Disable tests, examples, server
# - Use internal ggml (not system-installed)
# - Enable SIMD optimizations

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

# GGML options
GGML_ARGS=(
    -DGGML_CCACHE=OFF
    -DGGML_OPENCL=ON
    -DGGML_NATIVE=OFF
)

# SIMD optimizations for x86_64 (similar to MinGW script)
if [ "$BUILD_ARCH" == "amd64" ]; then
    GGML_ARGS+=(
        -DGGML_SSE42=ON
        -DGGML_AVX=ON
        -DGGML_F16C=ON
        -DGGML_AVX2=ON
        -DGGML_BMI2=ON
        -DGGML_FMA=ON
    )
fi

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

# Add Vulkan if enabled
if [ -n "$VULKAN_SDK" ] && [ -d "$VULKAN_SDK" ]; then
    GGML_LIBS="$GGML_LIBS -lggml-vulkan"
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
Libs: -L\${libdir} -lwhisper
Libs.private: $GGML_LIBS
Requires: OpenCL
EOF

# If Vulkan is enabled, add it to pkg-config
if [ -n "$VULKAN_SDK" ] && [ -d "$VULKAN_SDK" ]; then
    echo "Requires: OpenCL vulkan" >> "$INSTALL_PREFIX/lib/pkgconfig/whisper.pc"
fi

echo "whisper.cpp built successfully"
