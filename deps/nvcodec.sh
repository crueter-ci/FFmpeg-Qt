#!/bin/sh -e

_dir="$ROOTDIR/ffnvcodec-headers"
_url="https://github.com/FFmpeg/nv-codec-headers.git"
_name=nv-codec-headers

if [ ! -d "$_dir" ]; then
    echo "-- Building $_name..."
    cd "$ROOTDIR/$BUILD_DIR"

    [ -d "$_name" ] || git clone "$_url" --depth 1
    cd "$_name"

    make -j"$(nproc)" PREFIX="$_dir" install

    cd "$ROOTDIR"
fi

export FFNVCODEC_HEADERS_DIR="$_dir"
