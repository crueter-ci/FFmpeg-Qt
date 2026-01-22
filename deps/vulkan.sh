#!/bin/sh -e

_dir="$ROOTDIR/vulkan"
BUILD_DIR="${BUILD_DIR:-build}"

# headers
_url="https://github.com/KhronosGroup/Vulkan-Headers.git"
_name="Vulkan-Headers"

if [ ! -d "$_dir/include" ]; then
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

# loader
_url="https://github.com/KhronosGroup/Vulkan-Loader.git"
_name="Vulkan-Loader"

if [ ! -f "$_dir/lib/libvulkan.so.1" ]; then
    echo "-- Building $_name..."
    cd "$ROOTDIR/$BUILD_DIR"

    [ -d "$_name" ] || git clone "$_url" --depth 1
    cd "$_name"

    mkdir -p build
    cd build
    cmake .. -DCMAKE_INSTALL_PREFIX="$_dir" -DVULKAN_HEADERS_INSTALL_DIR="$_dir"

    make -j"$(nproc)"
    make install

    cd "$ROOTDIR"
fi

export VULKAN_DIR="$_dir"
