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

# Create cross file for Windows MSVC
cat > cross_file.txt << EOF
[host_machine]
system = 'windows'
cpu_family = '$MESON_CPU_FAMILY'
cpu = '$MESON_CPU'
endian = 'little'

[binaries]
c = 'cl'
cpp = 'cl'
ar = 'lib'
strip = 'echo'

[properties]
c_args = ['-MT']
cpp_args = ['-MT']
EOF

meson setup "$SRC_DIR" . --cross-file cross_file.txt --prefix "$INSTALL_PREFIX" --buildtype=release --default-library=static $@
meson compile -j$(nproc)
meson install