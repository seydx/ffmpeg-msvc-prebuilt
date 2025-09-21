#!/bin/bash
# Copyright (c) 2024 System233
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

HELP_MSG="Usage: build.sh <x86,amd64,arm,arm64> ...FF_ARGS"
set -e
source ./env.sh

if [ -z $BUILD_ARCH ]; then
    echo "$HELP_MSG" >&2
    exit 1
fi

shift 1 || true
FF_ARGS=$@

echo "Checking available dependencies in FFmpeg/configure..."
for dep in libharfbuzz libfreetype sdl libjxl libvpx libwebp libass libopus libvorbis libdav1d libsvtav1 libmp3lame libfdk-aac libvpl; do
    env_name="${dep//-/_}"
    env_var="ENABLE_${env_name^^}"

    # For configure check: use original dep name
    echo -n "Checking $dep... "
    if grep -q "enable-${dep}" FFmpeg/configure; then
        export ${env_var}=1
        echo "ENABLED (${env_var}=1)"
    else
        echo "not found in configure"
    fi
done

echo BUILD_ARCH=$BUILD_ARCH
echo FF_ARGS=$FF_ARGS

add_ffargs() {
    FF_ARGS="$FF_ARGS $@"
}

apply-patch() {
    GIT_CMD="git -C $1 apply $(pwd)/patches/$2 --ignore-whitespace"
    if ! $GIT_CMD -R --check 2>/dev/null; then
        echo Apply $2 for $1
        $GIT_CMD
    else
        echo Skip $2 for $1
    fi
}

apply-patch zlib zlib.patch
apply-patch FFmpeg ffmpeg.patch
apply-patch harfbuzz harfbuzz.patch

# Apply all Jellyfin patches to FFmpeg using quilt
if [ -d "patches/jellyfin" ]; then
    echo "Applying Jellyfin patches to FFmpeg with quilt..."
    export QUILT_PATCHES="../patches/jellyfin"
    cd FFmpeg
    quilt push -a -v || echo "Note: Some patches could not be applied"
    cd ..
fi

# zlib
./build-cmake-dep.sh zlib -DZLIB_BUILD_EXAMPLES=OFF
add_ffargs "--enable-zlib"

# ========================================
# Hardware
# ========================================

# Windows DirectX/D3D acceleration
add_ffargs "--enable-dxva2 --enable-d3d11va --enable-d3d12va"

# MediaFoundation
if [ "$BUILD_ARCH" == "arm64" ] || [ "$BUILD_ARCH" == "arm" ]; then
    add_ffargs "--enable-mediafoundation"
fi

# NVIDIA
./build-nvcodec.sh  # Install headers for all architectures
if [ "$BUILD_ARCH" != "arm64" ] && [ "$BUILD_ARCH" != "arm" ]; then
    add_ffargs "--enable-ffnvcodec --enable-cuda --enable-cuda-llvm --enable-cuvid --enable-nvdec --enable-nvenc"
fi

# OpenCL support for GPU-accelerated filters
./build-opencl.sh
add_ffargs "--enable-opencl"

# AMD AMF headers
echo -e "\n[Install AMF headers]"
if [ -d "AMF/amf/public/include" ]; then
    mkdir -p "$INSTALL_PREFIX/include"
    cp -r AMF/amf/public/include/* "$INSTALL_PREFIX/include/"
    echo "AMD AMF headers installed"
    add_ffargs "--enable-amf"
fi

# Intel QuickSync Video acceleration via oneVPL
if [ -n "$ENABLE_LIBVPL" ]; then
    ./build-vpl.sh
    add_ffargs "--enable-libvpl"
fi

# ========================================
# Video Decoder/Encoder
# ========================================

# dav1d - AV1 decoder
if [ -n "$ENABLE_LIBDAV1D" ]; then
    add_ffargs "--enable-libdav1d"
fi

# SVT-AV1 - AV1 encoder
if [ -n "$ENABLE_LIBSVTAV1" ]; then
    # Disable assembly for ARM64 due to CMake/ASM compiler issues
    if [ "$BUILD_ARCH" == "arm64" ]; then
        SVT_ASM_FLAGS="-DCOMPILE_C_ONLY=ON"
    else
        SVT_ASM_FLAGS="-DENABLE_NASM=ON"
    fi

    ./build-cmake-dep.sh svt-av1 \
        -DBUILD_APPS=OFF \
        -DBUILD_DEC=OFF \
        -DBUILD_TESTING=OFF \
        $SVT_ASM_FLAGS
    add_ffargs "--enable-libsvtav1"
fi

# x265 - HEVC encoder
apply-patch x265_git x265_git-static.patch

X265_ARGS="-DSTATIC_LINK_CRT=ON"
ENABLE_SHARED=OFF

git -C x265_git fetch --tags
./build-cmake-dep.sh x265_git/source -DCMAKE_SYSTEM_NAME=Windows -DENABLE_SHARED=OFF -DENABLE_CLI=OFF $X265_ARGS
add_ffargs "--enable-libx265"

# x264 - H.264 encoder
if [ "$BUILD_ARCH" == "arm64" ]; then
    X264_ARGS="--disable-asm"
fi

INSTALL_TARGET=install-lib-static ./build-make-dep.sh x264 --enable-static $X264_ARGS
add_ffargs "--enable-libx264"

# ========================================
# Audio Decoder/Encoder
# ========================================

# LAME MP3 encoder
if [ -n "$ENABLE_LIBMP3LAME" ]; then
    add_ffargs "--enable-libmp3lame"
fi

# FDK-AAC - AAC encoder
if [ -n "$ENABLE_LIBFDK_AAC" ]; then
    ./build-cmake-dep.sh fdk-aac -DBUILD_PROGRAMS=OFF
    add_ffargs "--enable-libfdk-aac --enable-nonfree"
fi

# ========================================
# Video Codecs
# ========================================

# VP8/VP9 video codec
if [ -n "$ENABLE_LIBVPX" ]; then
    case $BUILD_ARCH in
    amd64) libvpx_target=x86_64-win64-vs17 ;;
    arm64) libvpx_target=arm64-win64-vs17 ;;
    esac

    LIBVPX_ARGS="--enable-static-msvcrt"
    apply-patch libvpx libvpx.patch
    CFLAGS="" AS=yasm AR=lib ARFLAGS= CC=cl CXX=cl LD=link STRIP=false target= ./build-make-dep.sh libvpx --target=$libvpx_target --as=yasm --disable-optimizations --disable-dependency-tracking --disable-runtime-cpu-detect --disable-thumb --disable-neon --enable-external-build --disable-unit-tests --disable-decode-perf-tests --disable-encode-perf-tests --disable-tools --disable-examples $LIBVPX_ARGS
    add_ffargs "--enable-libvpx"
fi

# ========================================
# Audio Codecs
# ========================================

# Opus audio codec
if [ -n "$ENABLE_LIBOPUS" ]; then
    ./build-cmake-dep.sh opus -DOPUS_BUILD_PROGRAMS=OFF -DOPUS_BUILD_TESTING=OFF
    add_ffargs "--enable-libopus"
fi

# Vorbis audio codec
if [ -n "$ENABLE_LIBVORBIS" ]; then
    # Build libogg first (dependency for libvorbis)
    ./build-cmake-dep.sh libogg -DBUILD_TESTING=OFF
    # Build libvorbis with libogg
    ./build-cmake-dep.sh libvorbis -DBUILD_TESTING=OFF
    add_ffargs "--enable-libvorbis"
fi

# ========================================
# IMAGE FORMATS
# ========================================

# JPEG XL
if [ -n "$ENABLE_LIBJXL" ]; then
    apply-patch libjxl libjxl.patch
    ./build-cmake-dep.sh openexr -DOPENEXR_INSTALL_TOOLS=OFF -DOPENEXR_BUILD_TOOLS=OFF -DBUILD_TESTING=OFF -DOPENEXR_IS_SUBPROJECT=ON
    ./build-cmake-dep.sh libjxl -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_JNI=OFF -DJPEGXL_BUNDLE_LIBPNG=OFF -DJPEGXL_ENABLE_TOOLS=OFF -DJPEGXL_ENABLE_EXAMPLES=OFF -DJPEGXL_STATIC=ON
    add_ffargs "--enable-libjxl"
fi

# WebP image format
if [ -n "$ENABLE_LIBWEBP" ]; then
    ./build-cmake-dep.sh libwebp -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF
    add_ffargs "--enable-libwebp"
fi

# ========================================
# TEXT/SUBTITLE RENDERING
# ========================================

# FreeType - Font rendering
if [ -n "$ENABLE_LIBFREETYPE" ]; then
    ./build-cmake-dep.sh freetype
    add_ffargs "--enable-libfreetype"
fi

# HarfBuzz - Text shaping
if [ -n "$ENABLE_LIBHARFBUZZ" ]; then
    ./build-cmake-dep.sh harfbuzz -DHB_HAVE_FREETYPE=ON
    add_ffargs "--enable-libharfbuzz"
fi

# libass - ASS/SSA subtitle rendering
if [ -n "$ENABLE_LIBASS" ]; then
    # apply-patch fribidi fribidi.patch
    ./build-libass.sh
    add_ffargs "--enable-libass"
fi

# ========================================
# Windows Native Features
# ========================================

add_ffargs "--enable-schannel"
add_ffargs "--enable-lzma"

# Build FFmpeg
./build-ffmpeg.sh FFmpeg $FF_ARGS
./reprefix.sh
