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
EXTRA_CFLAGS=""
EXTRA_LDFLAGS="-LIBPATH:D:/a/_temp/msys64/usr/local/lib"
EXTRA_LIBS=""

EX_BUILD_ARGS="$TYPE_ARGS $CROSS_ARGS $LICENSE_ARGS $DISABLE_ARGS"

if [ -n "$VULKAN_SDK" ] && [ -d "$VULKAN_SDK" ]; then
    VULKAN_PATH_SHORT=$(cygpath -sw "$VULKAN_SDK")
    VULKAN_PATH_FIXED=$(cygpath -m "$VULKAN_PATH_SHORT")
    EXTRA_CFLAGS="$EXTRA_CFLAGS -I${VULKAN_PATH_FIXED}/Include"

    # Use architecture-specific lib directory
    if [ "$BUILD_ARCH" == "arm64" ]; then
        EXTRA_LDFLAGS="$EXTRA_LDFLAGS -LIBPATH:${VULKAN_PATH_FIXED}/Lib-ARM64"
    else
        EXTRA_LDFLAGS="$EXTRA_LDFLAGS -LIBPATH:${VULKAN_PATH_FIXED}/Lib"
    fi
fi

if [ "$BUILD_ARCH" != "arm64" ] && [ "$BUILD_ARCH" != "arm" ] && [ -n "$CUDA_PATH" ] && [ -f "$CUDA_PATH/bin/nvcc.exe" ]; then
    CUDA_PATH_SHORT=$(cygpath -sw "$CUDA_PATH")
    CUDA_PATH_FIXED=$(cygpath -m "$CUDA_PATH_SHORT")
    EXTRA_CFLAGS="$EXTRA_CFLAGS -I${CUDA_PATH_FIXED}/include"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS -LIBPATH:${CUDA_PATH_FIXED}/lib/x64"
    NVCC_FLAGS="-gencode arch=compute_61,code=compute_61 -O2"

    echo "Configure command: ./configure --toolchain=msvc --arch=$BUILD_ARCH --extra-cflags=\"$EXTRA_CFLAGS\" --extra-ldflags=\"$EXTRA_LDFLAGS\" --extra-libs=\"$EXTRA_LIBS\" --nvccflags=\"$NVCC_FLAGS\" $EX_BUILD_ARGS $@"
    echo "CFLAGS: $CFLAGS"

    CFLAGS="$CFLAGS" ./configure --toolchain=msvc --arch=$BUILD_ARCH \
        --extra-cflags="$EXTRA_CFLAGS" \
        --extra-ldflags="$EXTRA_LDFLAGS" \
        --extra-libs="$EXTRA_LIBS" \
        --nvccflags="$NVCC_FLAGS" \
        $EX_BUILD_ARGS $@
else
    echo "Configure command: ./configure --toolchain=msvc --arch=$BUILD_ARCH --extra-cflags=\"$EXTRA_CFLAGS\" --extra-ldflags=\"$EXTRA_LDFLAGS\" --extra-libs=\"$EXTRA_LIBS\" $EX_BUILD_ARGS $@"
    echo "CFLAGS: $CFLAGS"

    CFLAGS="$CFLAGS" ./configure --toolchain=msvc --arch=$BUILD_ARCH \
        --extra-cflags="$EXTRA_CFLAGS" \
        --extra-ldflags="$EXTRA_LDFLAGS" \
        --extra-libs="$EXTRA_LIBS" \
        $EX_BUILD_ARGS $@
fi

make -j$(nproc)
make install prefix=$INSTALL_PREFIX