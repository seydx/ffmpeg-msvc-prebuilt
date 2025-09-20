#!/bin/bash
# Copyright (c) 2024 System233
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -e
echo -e "\n[Build lame]"
SRC_DIR=$(pwd)/lame

export TOOLCHAIN_SRCDIR="$(pwd)/toolchain"
export AR=win-ar
export RANLIB=win-ranlib
export PATH=$TOOLCHAIN_SRCDIR:$PATH

cd $SRC_DIR

# Map our BUILD_ARCH to configure host triplet
case $BUILD_ARCH in
    amd64) HOST_TRIPLET="x86_64-w64-mingw32" ;;
    arm64) HOST_TRIPLET="aarch64-w64-mingw32" ;;
    *) HOST_TRIPLET="${BUILD_ARCH}-w64-mingw32" ;;
esac

# Configure for static library only
./configure "--host=${HOST_TRIPLET}" \
    --prefix=$INSTALL_PREFIX \
    --disable-shared \
    --enable-static \
    --disable-frontend \
    --disable-decoder \
    --disable-analyzer-hooks \
    --disable-dependency-tracking \
    CC=cl \
    AR=lib \
    CFLAGS="$CFLAGS"

# Build
make -j$(nproc)

# Install
make install