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
NOCONFIGURE=1 ./autogen.sh || true  # autogen might not exist, use configure directly if available

if [ ! -f configure ]; then
    echo "Error: configure script not found"
    exit 1
fi

# MSVC-specific CFLAGS
LAME_CFLAGS="$CFLAGS -DHAVE_CONFIG_H"

./configure "--host=${BUILD_ARCH}-windows" \
    --prefix=$INSTALL_PREFIX \
    --disable-shared \
    --enable-static \
    --disable-frontend \
    --disable-decoder \
    --disable-analyzer-hooks \
    --disable-dependency-tracking \
    CFLAGS="$LAME_CFLAGS"

make -j$(nproc) CFLAGS="$LAME_CFLAGS"
make install