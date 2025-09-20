#!/bin/bash
# Copyright (c) 2024 System233
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

LICENSE_ARGS="--enable-gpl --enable-version3"
CFLAGS="$CFLAGS -I${SRC_DIR}/compat/stdbit"
EX_BUILD_ARGS="$TYPE_ARGS $CROSS_ARGS $LICENSE_ARGS"

CFLAGS="$CFLAGS" ./configure --toolchain=msvc --arch=$BUILD_ARCH $EX_BUILD_ARGS $@
# iconv -f gbk config.h >config.h.tmp && mv config.h.tmp config.h
make -j$(nproc)
make install prefix=$INSTALL_PREFIX
