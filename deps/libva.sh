#!/bin/sh -e

_dir="$ROOTDIR/libva"
_url="https://github.com/intel/libva.git"
_name=libva
_start="$PWD"

if [ ! -d "$_dir" ]; then
	echo "-- Building $_name..."
	cd "$_start"
	[ -d "$_name" ] || git clone "$_url" --depth 1 "$_name"
	cd "$_name"

	./autogen.sh
	./configure --prefix "$_dir" --enable-shared

	make -j"$(nproc)"
	make install

	cd "$_start"
fi

export LIBVA_DIR="$_dir"
export PKG_CONFIG_PATH="$LIBVA_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
