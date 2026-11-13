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

# The jellyfin HEVC Rext DXVA struct marks its anonymous union and struct with
# MinGW's __C89_NAMELESS, which MSVC lacks but needs no keyword for
CFLAGS="$CFLAGS -D__C89_NAMELESS="

# Add library paths for MSVC
EXTRA_CFLAGS=""
EXTRA_LDFLAGS="-LIBPATH:D:/a/_temp/msys64/usr/local/lib /NODEFAULTLIB:msvcrt.lib /NODEFAULTLIB:msvcrtd.lib /NODEFAULTLIB:msvcprt.lib /NODEFAULTLIB:msvcprtd.lib /NODEFAULTLIB:vcruntime.lib /NODEFAULTLIB:vcruntimed.lib /NODEFAULTLIB:ucrt.lib /NODEFAULTLIB:ucrtd.lib"
EXTRA_LIBS="libcmt.lib libvcruntime.lib libucrt.lib"

EX_BUILD_ARGS="$TYPE_ARGS $CROSS_ARGS $LICENSE_ARGS $DISABLE_ARGS"

# Note: Vulkan headers and library come from Vulkan-Shim-Loader in /usr/local
# (already in EXTRA_CFLAGS and EXTRA_LDFLAGS via default paths)

echo "Configure command: ./configure --toolchain=msvc --arch=$BUILD_ARCH --extra-cflags=\"$EXTRA_CFLAGS\" --extra-ldflags=\"$EXTRA_LDFLAGS\" --extra-libs=\"$EXTRA_LIBS\" $EX_BUILD_ARGS $@"
echo "CFLAGS: $CFLAGS"

CFLAGS="$CFLAGS" ./configure --toolchain=msvc --arch=$BUILD_ARCH \
    --extra-cflags="$EXTRA_CFLAGS" \
    --extra-ldflags="$EXTRA_LDFLAGS" \
    --extra-libs="$EXTRA_LIBS" \
    $EX_BUILD_ARGS $@

make -j$(nproc)
make install prefix=$INSTALL_PREFIX