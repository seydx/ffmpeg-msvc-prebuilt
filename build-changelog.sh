#!/bin/bash
# Copyright (c) 2024 System233
# Copyright (c) 2025 seydx
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

cat RELEASE.md
flag=0
while IFS= read -r line; do
    if [[ "$line" =~ ^version ]]; then
        flag=$((flag + 1))
    fi
    if [[ $flag == 1 ]]; then
        echo $line
    elif [[ $flag == 2 ]]; then
        break
    fi
done <FFmpeg/Changelog
