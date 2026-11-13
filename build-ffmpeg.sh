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

# The variant (FF_VARIANT) only changes FFmpeg's configuration: the dependencies are shared
# by all variants and cached once, a library the variant leaves out is just not enabled.
# gpl is node-av, lgpl node-av-lgpl and light node-av-light.
case "${FF_VARIANT:-gpl}" in
gpl)
    LICENSE_ARGS="--enable-gpl --enable-version3"
    VARIANT_DROP=""
    ;;
lgpl)
    # No GPL encoders, and no libfdk_aac: it has its own license, lgpl stays plain LGPL
    LICENSE_ARGS="--enable-version3"
    VARIANT_DROP="--enable-libx264 --enable-libx265 --enable-libfdk-aac"
    ;;
light)
    # Without the less common external libraries, as in jellyfin-ffmpeg's builder/variants/defaults-light.sh
    LICENSE_ARGS="--enable-gpl --enable-version3"
    VARIANT_DROP="--enable-whisper --enable-libjxl --enable-libsvtav1 --enable-libvpx --enable-libwebp --enable-libvorbis --enable-libass --enable-libzimg"
    ;;
*)
    echo "Unknown FF_VARIANT ${FF_VARIANT}, expected gpl, lgpl or light" >&2
    exit 1
    ;;
esac

VARIANT_ARGS=()
for arg in "$@"; do
    if [[ " $VARIANT_DROP " == *" $arg "* ]]; then
        echo "Variant ${FF_VARIANT:-gpl} leaves out $arg"
    else
        VARIANT_ARGS+=("$arg")
    fi
done
set -- "${VARIANT_ARGS[@]}"

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