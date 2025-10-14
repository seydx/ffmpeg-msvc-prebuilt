#!/bin/bash
# Copyright (c) 2024 System233
# Copyright (c) 2025 seydx
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
for dep in libharfbuzz libfreetype libjxl libvpx libwebp libass libopus libvorbis libdav1d libsvtav1 libmp3lame libfdk-aac libvpl libzimg libx264 libx265 libglslang; do
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
    echo "Adding FFmpeg configure arg: $@"
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

# Apply patches
echo "Applying patches..."
apply-patch zlib zlib.patch
apply-patch FFmpeg ffmpeg-glslang-msvc.patch
apply-patch harfbuzz harfbuzz.patch

# Apply all Jellyfin patches
export QUILT_PATCHES="../patches/jellyfin"
cd FFmpeg
quilt push -a -v || echo "Note: Some patches could not be applied"
cd ..

# Copy FFMPEG_VERSION file to FFmpeg directory (used by patches)
if [ -f "FFMPEG_VERSION" ]; then
    echo "Copying FFMPEG_VERSION to FFmpeg directory..."
    cp FFMPEG_VERSION FFmpeg/
fi

# ========================================
# Others
# ========================================

# zlib
./build-cmake-dep.sh zlib -DZLIB_BUILD_EXAMPLES=OFF
add_ffargs "--enable-zlib"

# XZ/LZMA
./build-cmake-dep.sh xz -DENABLE_NLS=OFF -DBUILD_TESTING=OFF
if [ -f "$INSTALL_PREFIX/lib/lzma.lib" ]; then
    cp "$INSTALL_PREFIX/lib/lzma.lib" "$INSTALL_PREFIX/lib/liblzma.lib"
fi
add_ffargs "--enable-lzma"

# win-iconv
./build-cmake-dep.sh win-iconv
# For static linking, we need to ensure FFmpeg uses libiconv.lib (static) not iconv.lib (DLL import)
# Remove the DLL import library to force static linking
if [ -f "$INSTALL_PREFIX/lib/iconv.lib" ] && [ -f "$INSTALL_PREFIX/lib/libiconv.lib" ]; then
    mv "$INSTALL_PREFIX/lib/iconv.lib" "$INSTALL_PREFIX/lib/iconv_dll.lib"
    cp "$INSTALL_PREFIX/lib/libiconv.lib" "$INSTALL_PREFIX/lib/iconv.lib"
fi
add_ffargs "--enable-iconv"

# libxml2
./build-cmake-dep.sh libxml2 -DLIBXML2_WITH_ICONV=ON -DLIBXML2_WITH_LZMA=ON -DLIBXML2_WITH_ZLIB=ON -DLIBXML2_WITH_PYTHON=OFF -DLIBXML2_WITH_TESTS=OFF -DLIBXML2_WITH_PROGRAMS=OFF
# FFmpeg's pkg-config file says "-lxml2" which means it looks for xml2.lib
# But CMake builds libxml2s.lib (s for static)
if [ -f "$INSTALL_PREFIX/lib/libxml2s.lib" ]; then
    cp "$INSTALL_PREFIX/lib/libxml2s.lib" "$INSTALL_PREFIX/lib/xml2.lib"
    cp "$INSTALL_PREFIX/lib/libxml2s.lib" "$INSTALL_PREFIX/lib/libxml2.lib"
fi
add_ffargs "--enable-libxml2"

# ========================================
# Hardware
# ========================================

# Windows DirectX/D3D acceleration
add_ffargs "--enable-dxva2 --enable-d3d11va --enable-d3d12va"

# MediaFoundation
if [ "$BUILD_ARCH" == "arm64" ] || [ "$BUILD_ARCH" == "arm" ]; then
    echo "Enabling MediaFoundation for ARM"
    add_ffargs "--enable-mediafoundation"
fi

# NVIDIA
if [ "$BUILD_ARCH" != "arm64" ] && [ "$BUILD_ARCH" != "arm" ]; then
    ./build-nvcodec.sh
    add_ffargs "--enable-ffnvcodec --enable-cuda --enable-cuvid --enable-nvdec --enable-nvenc"

    # Check if CUDA SDK is available (installed via GitHub Action)
    if [ -n "$CUDA_PATH" ] && [ -f "$CUDA_PATH/bin/nvcc.exe" ]; then
        echo "CUDA SDK found, enabling CUDA NVCC support in FFmpeg"
        add_ffargs "--enable-cuda-nvcc"

        # Enable libnpp for CUDA-accelerated filters (not static?)
        # add_ffargs "--enable-libnpp --enable-nonfree"
    fi
fi

# OpenCL
./build-opencl.sh
add_ffargs "--enable-opencl"

# Whisper.cpp - Speech-to-Text (requires FFmpeg 8+)
# if [ -n "$ENABLE_WHISPER" ] && [ "$BUILD_ARCH" == "amd64" ]; then
#     ./build-whisper.sh
#     add_ffargs "--enable-whisper"
# fi

# AMD AMF
if [ "$BUILD_ARCH" != "arm64" ] && [ "$BUILD_ARCH" != "arm" ]; then
    echo -e "\n[Build AMF headers]"
    if [ -d "AMF/amf/public/include" ]; then
        mkdir -p "$INSTALL_PREFIX/include/AMF"
        cp -r AMF/amf/public/include/* "$INSTALL_PREFIX/include/AMF/"
        add_ffargs "--enable-amf"
    fi
fi

# Intel QuickSync
if [ -n "$ENABLE_LIBVPL" ] && [ "$BUILD_ARCH" != "arm64" ] && [ "$BUILD_ARCH" != "arm" ]; then
    ./build-vpl.sh
    add_ffargs "--enable-libvpl"
fi

# Vulkan/glslang
if [ -n "$ENABLE_LIBGLSLANG" ]; then
    # Vulkan support
    echo -e "\n[Build Vulkan]"

    # Install Vulkan headers
    mkdir -p "$INSTALL_PREFIX/include"
    cp -r vulkan-headers/include/* "$INSTALL_PREFIX/include/"

    # Build SPIRV-Headers
    mkdir -p "$INSTALL_PREFIX/include/spirv"
    cp -r spirv-headers/include/spirv/* "$INSTALL_PREFIX/include/spirv/"

    # Build SPIRV-Tools
    ./build-cmake-dep.sh spirv-tools \
        -DSPIRV-Headers_SOURCE_DIR=$(pwd)/spirv-headers \
        -DSPIRV_SKIP_TESTS=ON \
        -DSPIRV_SKIP_EXECUTABLES=ON

    # Build glslang
    ./build-cmake-dep.sh glslang \
        -DBUILD_EXTERNAL=OFF \
        -DALLOW_EXTERNAL_SPIRV_TOOLS=ON \
        -DSPIRV-Tools-opt_DIR="$INSTALL_PREFIX/SPIRV-Tools-opt/cmake" \
        -DSPIRV-Tools_DIR="$INSTALL_PREFIX/SPIRV-Tools/cmake" \
        -DBUILD_TESTING=OFF \
        -DENABLE_GLSLANG_BINARIES=OFF \
        -DENABLE_HLSL=ON \
        -DENABLE_CTEST=OFF \
        -DENABLE_OPT=ON \
        -DBUILD_SHARED_LIBS=OFF

    # Create pkg-config file for glslang so FFmpeg can find it with our patch
    mkdir -p "$INSTALL_PREFIX/lib/pkgconfig"

    # Note: glslang 14.0.0+ removed separate HLSL, OGLCompiler, and SPVRemapper libraries
    # - HLSL sources are now compiled directly into glslang when ENABLE_HLSL=ON
    # - OGLCompiler and SPVRemapper were stub libraries that have been removed
    # - MachineIndependent, GenericCodeGen, OSDependent are stub libraries (contain only stub.cpp)
    #   but we include them for completeness since they exist and some build systems may expect them
    GLSLANG_LIBS="-lglslang -lMachineIndependent -lGenericCodeGen -lOSDependent -lSPIRV -lSPIRV-Tools-opt -lSPIRV-Tools"

    cat > "$INSTALL_PREFIX/lib/pkgconfig/glslang.pc" << EOF
prefix=$INSTALL_PREFIX
includedir=\${prefix}/include
libdir=\${prefix}/lib

Name: glslang
Description: Khronos reference compiler and validator for GLSL, ESSL, and HLSL
Version: 1.4.328.1
Cflags: -I\${includedir}
Libs: -L\${libdir} $GLSLANG_LIBS
EOF

    add_ffargs "--enable-libglslang"

    if [ -n "$VULKAN_SDK" ] && [ -d "$VULKAN_SDK" ]; then
        echo "VULKAN_SDK is set, enabling Vulkan support in FFmpeg"
        add_ffargs "--enable-vulkan"
    fi
fi

# ========================================
# Video Decoder/Encoder
# ========================================

# dav1d - AV1 decoder
if [ -n "$ENABLE_LIBDAV1D" ]; then
    echo -e "\n[Build dav1d]"
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
if [ -n "$ENABLE_LIBX265" ]; then
    apply-patch x265_git x265_git-static.patch

    X265_ARGS="-DSTATIC_LINK_CRT=ON"
    ENABLE_SHARED=OFF

    git -C x265_git fetch --tags
    ./build-cmake-dep.sh x265_git/source -DCMAKE_SYSTEM_NAME=Windows -DENABLE_SHARED=OFF -DENABLE_CLI=OFF $X265_ARGS
    add_ffargs "--enable-libx265"
fi

# x264 - H.264 encoder
if [ -n "$ENABLE_LIBX264" ]; then
    if [ "$BUILD_ARCH" == "arm64" ]; then
        X264_ARGS="--disable-asm"
    fi

    INSTALL_TARGET=install-lib-static ./build-make-dep.sh x264 --enable-static $X264_ARGS
    add_ffargs "--enable-libx264"
fi

# ========================================
# Audio Decoder/Encoder
# ========================================

# LAME MP3 encoder
if [ -n "$ENABLE_LIBMP3LAME" ]; then
    echo -e "\n[Build LAME]"
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

# libzimg
if [ -n "$ENABLE_LIBZIMG" ]; then
    echo -e "\n[Build zimg]"
    add_ffargs "--enable-libzimg"
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

# ========================================
# Build FFmpeg
# ========================================

./build-ffmpeg.sh FFmpeg $FF_ARGS
./reprefix.sh
