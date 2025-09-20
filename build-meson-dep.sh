#!/bin/bash
# Copyright (c) 2024 System233
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -e
echo -e "\n[Build $1]"
SRC_DIR=$(pwd)/$1
BUILD_DIR=build/$1
shift 1
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

case $BUILD_ARCH in
amd64)
    MESON_CPU=x86_64
    MESON_CPU_FAMILY=x86_64
    ;;
arm64)
    MESON_CPU=aarch64
    MESON_CPU_FAMILY=aarch64
    ;;
esac

# Find the actual paths to MSVC tools
CL_PATH=$(which cl.exe 2>/dev/null || echo "cl")
LIB_PATH=$(which lib.exe 2>/dev/null || echo "lib")

# Create cross file for Windows MSVC
cat > cross_file.txt << EOF
[host_machine]
system = 'windows'
cpu_family = '$MESON_CPU_FAMILY'
cpu = '$MESON_CPU'
endian = 'little'

[binaries]
c = '$CL_PATH'
cpp = '$CL_PATH'
ar = '$LIB_PATH'
strip = 'echo'

[built-in options]
c_args = ['-MT']
cpp_args = ['-MT']
EOF

# Meson checks MSYSTEM and complains if it's MINGW* but we're using MSVC
# Temporarily set it to MSYS to avoid the error
MSYSTEM=MSYS meson setup "$SRC_DIR" . --cross-file cross_file.txt --prefix "$INSTALL_PREFIX" --buildtype=release --default-library=static $@
meson compile -j$(nproc)
meson install