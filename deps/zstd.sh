#!/bin/sh -e

_url="https://github.com/facebook/zstd.git"
_name="zstd"
_dir="$ROOTDIR/zstd/out"

if ! command -v zstd >/dev/null 2>&1; then
	echo "-- Building $_name..."
	cd "$ROOTDIR/$BUILD_DIR"

	[ -d "$_name" ] || git clone "$_url" --depth 1
	cd "$_name"

	cmake -S . -B build -G "Ninja" -DCMAKE_INSTALL_PREFIX="$_dir"

	cmake --build build
	cmake --install build

	cd "$ROOTDIR"

	export PATH="$PATH:$_dir/bin"
fi