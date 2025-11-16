#!/bin/bash

set -e
echo -e "\n[Build whisper.cpp]"

SRC_DIR=$(pwd)/whisper.cpp
BUILD_DIR=build/whisper.cpp
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

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

# Fix ggml library names - MSVC builds them without 'lib' prefix (e.g., ggml.lib instead of libggml.lib)
ORIGINAL_DIR=$(pwd)
cd "$INSTALL_PREFIX/lib"
for libfile in ggml*.lib; do
    if [ -f "$libfile" ] && [ ! -f "lib${libfile}" ]; then
        echo "Creating lib${libfile} from ${libfile}"
        cp "${libfile}" "lib${libfile}"
    fi
done
cd "$ORIGINAL_DIR"

# Create pkg-config file for FFmpeg
mkdir -p "$INSTALL_PREFIX/lib/pkgconfig"

# whisper.cpp uses multiple ggml libraries that need to be linked in correct order
GGML_LIBS="-lggml -lggml-base -lggml-cpu -lggml-opencl"

# Add Vulkan if enabled (x64 only)
# Note: Vulkan libs must be added to Libs line because Vulkan SDK doesn't provide a .pc file
if [ -n "$VULKAN_SDK" ] && [ -d "$VULKAN_SDK" ]; then
    GGML_LIBS="$GGML_LIBS -lggml-vulkan"
    # Convert path using cygpath for proper Windows path handling
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
Version: 1.8.2
Requires: OpenCL
Cflags: -I\${includedir}
Libs: -L\${libdir} -lwhisper $VULKAN_LIBS
Libs.private: $GGML_LIBS -lstdc++
EOF

echo "whisper.cpp built successfully"
