#!/bin/sh -e

_dir="$ROOTDIR/vulkan-headers"
_url="https://github.com/KhronosGroup/Vulkan-Headers.git"
_name=Vulkan-Headers

if [ ! -d "$_dir" ]; then
    echo "-- Building $_name..."
    cd "$ROOTDIR/$BUILD_DIR"

    [ -d "$_name" ] || git clone "$_url" --depth 1
    cd "$_name"

    mkdir -p build
    cd build
    cmake .. -DCMAKE_INSTALL_PREFIX="$_dir"

    make -j"$(nproc)"
    make install

    cd "$ROOTDIR"
fi

export VULKAN_HEADERS_DIR="$_dir"
