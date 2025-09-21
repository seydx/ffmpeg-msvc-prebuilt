#!/bin/bash
# Build script for NVIDIA codec headers (ffnvcodec)

set -e
echo -e "\n[Build nv-codec-headers]"
SRC_DIR=$(pwd)/nv-codec-headers
cd $SRC_DIR

# Install headers
make install PREFIX=$INSTALL_PREFIX

# Make sure pkg-config file is in the right place
if [ -f "$INSTALL_PREFIX/lib/pkgconfig/ffnvcodec.pc" ]; then
    echo "ffnvcodec.pc found and installed correctly"
else
    echo "Creating ffnvcodec.pc manually"
    mkdir -p "$INSTALL_PREFIX/lib/pkgconfig"

    # Get version from the Makefile
    VERSION=$(grep "^VERSION" Makefile | cut -d'=' -f2 | tr -d ' ')

    cat > "$INSTALL_PREFIX/lib/pkgconfig/ffnvcodec.pc" << EOF
prefix=$INSTALL_PREFIX
exec_prefix=\${prefix}
includedir=\${prefix}/include

Name: ffnvcodec
Description: FFmpeg nvidia codec headers
Version: ${VERSION:-12.1.14.0}
Cflags: -I\${includedir}
EOF
fi

echo "nv-codec-headers installed successfully"