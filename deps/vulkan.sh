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

    cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX="$_dir"

    cmake --build build
    cmake --install build

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

    cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX="$_dir" -DVULKAN_HEADERS_INSTALL_DIR="$_dir"

    cmake --build build
    cmake --install build

    cd "$ROOTDIR"
fi

export VULKAN_DIR="$_dir"
