#!/bin/bash
# Copyright (c) 2024 System233
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

HELP_MSG="Usage: build.sh <x86,amd64,arm,arm64> [static,shared] [gpl,lgpl] ...FF_ARGS"
set -e
source ./env.sh

if [ -z $BUILD_ARCH ]; then
    echo "$HELP_MSG" >&2
    exit 1
fi

shift 3 || true
FF_ARGS=$@

echo "Checking available dependencies in FFmpeg/configure..."
for dep in libharfbuzz libfreetype sdl libjxl libvpx libwebp libass libopus libvorbis libdav1d libsvtav1 libmp3lame libfdk-aac libvpl; do
    # For environment variable: first replace - with _, then convert to uppercase
    env_name="${dep//-/_}"  # libfdk-aac -> libfdk_aac
    env_var="ENABLE_${env_name^^}"  # -> ENABLE_LIBFDK_AAC

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
echo BUILD_TYPE=$BUILD_TYPE
echo BUILD_LICENSE=$BUILD_LICENSE
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

# Windows DirectX/D3D acceleration (always available on Windows)
add_ffargs "--enable-dxva2 --enable-d3d11va --enable-d3d12va"

./build-make-dep.sh nv-codec-headers
add_ffargs "--enable-ffnvcodec --enable-cuda --enable-cuda-llvm --enable-cuvid --enable-nvdec --enable-nvenc"

./build-cmake-dep.sh zlib -DZLIB_BUILD_EXAMPLES=OFF
add_ffargs "--enable-zlib"

if [ -n "$ENABLE_LIBMP3LAME" ]; then
    add_ffargs "--enable-libmp3lame"
fi

# First build OpenCL headers
./build-cmake-dep.sh opencl-headers -DBUILD_TESTING=OFF

# Then build OpenCL ICD Loader
./build-cmake-dep.sh opencl-icd-loader \
    -DBUILD_SHARED_LIBS=OFF \
    -DOPENCL_ICD_LOADER_DISABLE_OPENCLON12=ON \
    -DOPENCL_ICD_LOADER_HEADERS_DIR="$INSTALL_PREFIX/include" \
    -DBUILD_TESTING=OFF

add_ffargs "--enable-opencl"

echo -e "\n[Install AMF headers]"
if [ -d "AMF/amf/public/include" ]; then
    mkdir -p "$INSTALL_PREFIX/include"
    cp -r AMF/amf/public/include/* "$INSTALL_PREFIX/include/"
    echo "AMD AMF headers installed"
    add_ffargs "--enable-amf"
fi

if [ -n "$ENABLE_LIBDAV1D" ]; then
    add_ffargs "--enable-libdav1d"
fi

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

if [ -n "$ENABLE_LIBFDK_AAC" ]; then
    ./build-cmake-dep.sh fdk-aac -DBUILD_PROGRAMS=OFF
    add_ffargs "--enable-libfdk-aac --enable-nonfree"
fi

if [ -n "$ENABLE_LIBVPL" ]; then
    ./build-cmake-dep.sh libvpl -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TOOLS=OFF -DBUILD_PREVIEW=OFF
    add_ffargs "--enable-libvpl"
fi

if [ -n "$ENABLE_LIBFREETYPE" ]; then
    ./build-cmake-dep.sh freetype
    add_ffargs "--enable-libfreetype"
fi

if [ -n "$ENABLE_LIBHARFBUZZ" ]; then
    ./build-cmake-dep.sh harfbuzz -DHB_HAVE_FREETYPE=ON
    add_ffargs "--enable-libharfbuzz"
fi

if [ -n "$ENABLE_LIBASS" ]; then
    # apply-patch fribidi fribidi.patch
    ./build-libass.sh
    add_ffargs "--enable-libass"
fi

if [ -n "$ENABLE_SDL" ]; then
    ./build-cmake-dep.sh SDL
    add_ffargs "--enable-sdl"
fi

if [ -n "$ENABLE_LIBJXL" ]; then

    if [ "$BUILD_TYPE" == "shared" ]; then
        JPEGXL_STATIC=OFF
    else
        JPEGXL_STATIC=ON
    fi

    apply-patch libjxl libjxl.patch
    ./build-cmake-dep.sh openexr -DOPENEXR_INSTALL_TOOLS=OFF -DOPENEXR_BUILD_TOOLS=OFF -DBUILD_TESTING=OFF -DOPENEXR_IS_SUBPROJECT=ON
    ./build-cmake-dep.sh libjxl -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_JNI=OFF -DJPEGXL_BUNDLE_LIBPNG=OFF -DJPEGXL_ENABLE_TOOLS=OFF -DJPEGXL_ENABLE_EXAMPLES=OFF -DJPEGXL_STATIC=$JPEGXL_STATIC
    add_ffargs "--enable-libjxl"

fi

if [ -n "$ENABLE_LIBOPUS" ]; then
    ./build-cmake-dep.sh opus -DOPUS_BUILD_PROGRAMS=OFF -DOPUS_BUILD_TESTING=OFF
    add_ffargs "--enable-libopus"
fi

if [ -n "$ENABLE_LIBVORBIS" ]; then
    # Build libogg first (dependency for libvorbis)
    ./build-cmake-dep.sh libogg -DBUILD_TESTING=OFF
    # Build libvorbis with libogg
    ./build-cmake-dep.sh libvorbis -DBUILD_TESTING=OFF
    add_ffargs "--enable-libvorbis"
fi

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

if [ -n "$ENABLE_LIBWEBP" ]; then
    ./build-cmake-dep.sh libwebp -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF
    add_ffargs "--enable-libwebp"
fi

if [ "$BUILD_LICENSE" == "gpl" ]; then

    # if [ -n "$ENABLE_LIBMP3LAME" ]; then
    #     ./build-lame.sh
    #     add_ffargs "--enable-libmp3lame"
    # fi

    apply-patch x265_git x265_git-${BUILD_TYPE}.patch

    if [ "$BUILD_TYPE" == "static" ]; then
        X265_ARGS="-DSTATIC_LINK_CRT=ON"
        ENABLE_SHARED=OFF
    else
        X265_ARGS="-DSTATIC_LINK_CRT=OFF"
        ENABLE_SHARED=ON
    fi


    git -C x265_git fetch --tags
    ./build-cmake-dep.sh x265_git/source -DCMAKE_SYSTEM_NAME=Windows -DENABLE_SHARED=$ENABLE_SHARED -DENABLE_CLI=OFF $X265_ARGS
    add_ffargs "--enable-libx265"

    if [ "$BUILD_TYPE" == "shared" ]; then
        apply-patch x264 x264-${BUILD_TYPE}.patch
    fi
    if [ "$BUILD_ARCH" == "arm64" ]; then
        X264_ARGS="--disable-asm"
    fi

    INSTALL_TARGET=install-lib-${BUILD_TYPE} ./build-make-dep.sh x264 --enable-${BUILD_TYPE} $X264_ARGS
    add_ffargs "--enable-libx264"

fi

./build-ffmpeg.sh FFmpeg $FF_ARGS
./reprefix.sh
