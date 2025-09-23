#!/bin/bash
# Build script for OpenCL ICD Loader with proper Windows library dependencies

set -e
echo -e "\n[Build opencl-headers]"

# Build OpenCL headers first
SRC_DIR=$(pwd)/opencl-headers
BUILD_DIR=build/opencl-headers
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$SRC_DIR" -G "NMake Makefiles" \
    --install-prefix "$INSTALL_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF

cmake --build . --config Release
cmake --install . --config Release

cd ../..

# Build OpenCL ICD Loader
echo "[Build opencl-icd-loader]"
SRC_DIR=$(pwd)/opencl-icd-loader
BUILD_DIR=build/opencl-icd-loader
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$SRC_DIR" -G "NMake Makefiles" \
    --install-prefix "$INSTALL_PREFIX" \
    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded \
    -DOPENCL_ICD_LOADER_DISABLE_OPENCLON12=ON \
    -DOPENCL_ICD_LOADER_REQUIRE_WDK=OFF \
    -DOPENCL_ICD_LOADER_HEADERS_DIR="$INSTALL_PREFIX/include" \
    -DBUILD_TESTING=OFF

cmake --build . --config Release -j$(nproc)
cmake --install . --config Release

cd ../..

# Create pkg-config file for OpenCL with Windows system libraries
echo "[Creating OpenCL pkg-config with system libraries]"
mkdir -p "$INSTALL_PREFIX/lib/pkgconfig"
cat > "$INSTALL_PREFIX/lib/pkgconfig/OpenCL.pc" << EOF
prefix=$INSTALL_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: OpenCL
Description: OpenCL ICD Loader
Version: 3.0
Libs: -L\${libdir} -lOpenCL -ladvapi32 -lole32 -lcfgmgr32
Cflags: -I\${includedir}
EOF

echo "OpenCL ICD Loader built and installed successfully"