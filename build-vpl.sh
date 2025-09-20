#!/bin/bash
# Build script specifically for libvpl with proper Windows library dependencies

set -e
echo -e "\n[Build libvpl]"
SRC_DIR=$(pwd)/libvpl
BUILD_DIR=build/libvpl
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

case $BUILD_ARCH in
amd64)
    BUILD_ARCH=x64
    ;;
arm64)
    BUILD_ARCH=ARM64
    ;;
esac

# Always static build with MT runtime
cmake "$SRC_DIR" -G "NMake Makefiles" \
    --install-prefix "$INSTALL_PREFIX" \
    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded \
    -DBUILD_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_TOOLS=OFF \
    -DBUILD_PREVIEW=OFF \
    -DUSE_MSVC_STATIC_RUNTIME=ON \
    -DMINGW_LIBS="-ladvapi32 -lole32 -lmsvcrt"

cmake --build . --config Release -j$(nproc)
cmake --install . --config Release