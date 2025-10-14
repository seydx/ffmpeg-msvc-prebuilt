#!/bin/bash
# Copyright (c) 2024 System233
# Copyright (c) 2025 seydx
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

cat RELEASE.md

# Read FFmpeg version from FFMPEG_VERSION file (e.g., "8.0")
# This defines the exact version we want to include in changelog
if [ -f "FFMPEG_VERSION" ]; then
    FFMPEG_VER=$(cat FFMPEG_VERSION | tr -d '[:space:]')
    echo "#### FFmpeg Changelog"
    echo ""
else
    echo "Warning: FFMPEG_VERSION file not found, defaulting to version 8.0" >&2
    FFMPEG_VER="8.0"
fi

# Read FFmpeg Changelog and include:
# 1. "version <next>:" if present (development changes)
# 2. The exact version specified in FFMPEG_VERSION (e.g., "version 8.0:")
in_version=0
version_count=0
while IFS= read -r line; do
    if [[ "$line" =~ ^version ]]; then
        # Check if this is <next> or the exact version we want
        if [[ "$line" =~ version\ \<next\> ]]; then
            in_version=1
            echo "$line"
        elif [[ "$line" =~ version\ ${FFMPEG_VER}: ]]; then
            in_version=1
            version_count=$((version_count + 1))
            echo "$line"
        else
            # Stop after we've printed the target version
            if [[ $version_count -gt 0 ]]; then
                break
            fi
            in_version=0
        fi
    elif [[ $in_version -eq 1 ]]; then
        # Print content lines while we're in a version section
        echo "$line"
    fi
done <FFmpeg/Changelog
