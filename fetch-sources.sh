#!/bin/bash
# Copyright (c) 2026 seydx
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Fetches FFmpeg and every dependency at the revisions sources.sh pins, as shallow
# clones (with their submodules) into the directories the build scripts use. A
# directory already holding its pinned revision is kept.

set -e
cd "$(dirname "$0")"
source ./sources.sh

SCRIPTS=FFmpeg/builder/scripts.d

# Clone <repository> at <revision> (commit or tag) into <directory>.
fetch() {
    local dir=$1 repo=$2 rev=$3
    local pin="$repo $rev"
    if [ "$(cat "$dir/.git/source-pin" 2>/dev/null)" = "$pin" ]; then
        echo "$dir: $rev (present)"
        return
    fi
    echo "$dir: $repo $rev"
    rm -rf "$dir"
    git init -q "$dir"
    git -C "$dir" remote add origin "$repo"
    # Servers that refuse fetching a commit by id get a full fetch instead
    if git -C "$dir" fetch -q --depth 1 origin "$rev"; then
        git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
    else
        git -C "$dir" fetch -q --tags origin
        git -C "$dir" -c advice.detachedHead=false checkout -q "$rev"
    fi
    if [ -f "$dir/.gitmodules" ]; then
        git -C "$dir" submodule -q update --init --recursive --depth 1
    fi
    echo "$pin" > "$dir/.git/source-pin"
}

# Value of VAR="..." in a jellyfin builder script.
script_var() {
    local value
    value=$(sed -n "s/^$2=\"\(.*\)\"$/\1/p" "$SCRIPTS/$1")
    [ -n "$value" ] || { echo "$2 not found in $SCRIPTS/$1" >&2; return 1; }
    echo "$value"
}

# "<repository> <revision>" of third_party/<dependency> in shaderc's DEPS file:
# 'third_party/x': Var('base') + '/x.git@' + Var('x_revision'), with both vars in vars.
shaderc_dep() {
    local deps base path rev
    deps=$(tr -d ' \n' < shaderc/DEPS)
    read -r base path rev <<< "$(sed -n "s|.*'third_party/$1':Var('\([a-z_]*\)')+'\([^@']*\)@'+Var('\([a-z_]*\)').*|\1 \2 \3|p" <<< "$deps")"
    [ -n "$rev" ] || { echo "third_party/$1 not found in shaderc/DEPS" >&2; return 1; }
    echo "$(sed -n "s|.*'$base':'\([^']*\)'.*|\1|p" <<< "$deps")$path $(sed -n "s|.*'$rev':'\([^']*\)'.*|\1|p" <<< "$deps")"
}

fetch FFmpeg "$JELLYFIN_REPO" "$JELLYFIN_COMMIT"

while read -r dir source rev; do
    [ -n "$dir" ] || continue
    case $source in
    jellyfin:*)
        IFS=: read -r _ script n <<< "$source"
        repo=$(script_var "$script" "SCRIPT_REPO$n")
        rev=$(script_var "$script" "SCRIPT_COMMIT$n")
        ;;
    shaderc:*)
        pin=$(shaderc_dep "${source#shaderc:}")
        repo=${pin% *}
        rev=${pin#* }
        ;;
    *)
        repo=$source
        ;;
    esac
    # stdin is the source list
    fetch "$dir" "$repo" "$rev" < /dev/null
done <<< "$SOURCES"
