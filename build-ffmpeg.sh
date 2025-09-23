#!/bin/bash
# Copyright (c) 2024 System233
# Copyright (c) 2025 seydx
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -e
echo -e "\n[Build $1]"
SRC_DIR=$(pwd)/$1
shift 1
cd $SRC_DIR

TYPE_ARGS="--enable-static --pkg-config-flags=--static"
if [ "$BUILD_ARCH" == "arm64" ]; then
    CROSS_ARGS="--enable-cross-compile --disable-asm"
fi

LICENSE_ARGS="--enable-gpl --enable-version3"

# Disable programs and features we don't need (same as Jellyfin)
DISABLE_ARGS="--disable-ffplay --disable-debug --disable-doc --disable-sdl2"
CFLAGS="$CFLAGS -I${SRC_DIR}/compat/stdbit"

# Add LZMA_API_STATIC for static linking with liblzma
CFLAGS="$CFLAGS -DLZMA_API_STATIC"

# Add library paths for MSVC
EXTRA_LDFLAGS="-LIBPATH:D:/a/_temp/msys64/usr/local/lib"
EXTRA_LIBS=""

EX_BUILD_ARGS="$TYPE_ARGS $CROSS_ARGS $LICENSE_ARGS $DISABLE_ARGS"

if [ "$BUILD_ARCH" != "arm64" ] && [ "$BUILD_ARCH" != "arm" ] && [ -n "$CUDA_PATH" ] && [ -f "$CUDA_PATH/bin/nvcc.exe" ]; then
    CUDA_PATH_SHORT=$(cygpath -sw "$CUDA_PATH")
    CUDA_PATH_FIXED=$(cygpath -m "$CUDA_PATH_SHORT")

    # Add CUDA paths for headers and libraries
    CUDA_CFLAGS="-I${CUDA_PATH_FIXED}/include"
    CUDA_LDFLAGS="-LIBPATH:${CUDA_PATH_FIXED}/lib/x64"

    # Use multiple gencode flags for broad GPU support:
    # - sm_61: GTX 10 series (Pascal) - native SASS code
    # - sm_75: RTX 20 series (Turing) - native SASS code
    # - sm_86: RTX 30 series (Ampere) - native SASS code
    # - compute_86: PTX for future GPUs (JIT compiled at runtime)
    NVCC_FLAGS="-gencode arch=compute_61,code=sm_61"
    NVCC_FLAGS="$NVCC_FLAGS -gencode arch=compute_75,code=sm_75"
    NVCC_FLAGS="$NVCC_FLAGS -gencode arch=compute_86,code=sm_86"
    NVCC_FLAGS="$NVCC_FLAGS -gencode arch=compute_86,code=compute_86 -O2"

    echo "Configure command: ./configure --toolchain=msvc --arch=$BUILD_ARCH --extra-cflags=\"$CUDA_CFLAGS\" --extra-ldflags=\"$EXTRA_LDFLAGS $CUDA_LDFLAGS\" --extra-libs=\"$EXTRA_LIBS\" --nvccflags=\"$NVCC_FLAGS\" $EX_BUILD_ARGS $@"
    echo "CFLAGS: $CFLAGS"

    CFLAGS="$CFLAGS" ./configure --toolchain=msvc --arch=$BUILD_ARCH \
        --extra-cflags="$CUDA_CFLAGS" \
        --extra-ldflags="$EXTRA_LDFLAGS $CUDA_LDFLAGS" \
        --extra-libs="$EXTRA_LIBS" \
        --nvccflags="$NVCC_FLAGS" \
        $EX_BUILD_ARGS $@
else
    echo "Configure command: ./configure --toolchain=msvc --arch=$BUILD_ARCH --extra-ldflags=\"$EXTRA_LDFLAGS\" --extra-libs=\"$EXTRA_LIBS\" $EX_BUILD_ARGS $@"
    echo "CFLAGS: $CFLAGS"

    CFLAGS="$CFLAGS" ./configure --toolchain=msvc --arch=$BUILD_ARCH \
        --extra-ldflags="$EXTRA_LDFLAGS" \
        --extra-libs="$EXTRA_LIBS" \
        $EX_BUILD_ARGS $@
fi

make -j$(nproc)
make install prefix=$INSTALL_PREFIX
