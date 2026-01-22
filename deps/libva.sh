#!/bin/sh -e

_dir="$ROOTDIR/libva"
_url="https://github.com/intel/libva.git"
_name=libva

if [ ! -d "$_dir" ]; then
	echo "-- Building $_name..."
	cd "$ROOTDIR/$BUILD_DIR"

	[ -d "$_name" ] || git clone "$_url" --depth 1
	cd "$_name"

	./autogen.sh
	./configure --prefix "$_dir" --enable-shared

	make -j"$(nproc)"
	make install

	cd "$ROOTDIR"
fi

export LIBVA_DIR="$_dir"