# Copyright (c) 2024 System233
# Copyright (c) 2025 seydx
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

export INSTALL_PREFIX=${INSTALL_PREFIX:-/usr/local}
export PKG_CONFIG_PATH=$INSTALL_PREFIX/lib/pkgconfig:$INSTALL_PREFIX/share/pkgconfig

export BUILD_ARCH=${1:-$VSCMD_ARG_TGT_ARCH}
export BUILD_TYPE=static
export BUILD_LICENSE=gpl

export CFLAGS="-MT"
export CMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded"
export CC=cl
export CXX=cl
