#!/bin/bash
# Copyright (c) 2025 seydx
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -e

echo "Fetching tags for all submodules..."

# Get all submodule paths
git submodule foreach --quiet 'echo $path' | while read submodule_path; do
    if [ -d "$submodule_path" ]; then
        echo "Fetching tags for: $submodule_path"
        git -C "$submodule_path" fetch --tags
    fi
done

echo "Done! All submodule tags fetched."
