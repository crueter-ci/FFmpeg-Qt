#!/bin/sh -e

_version=3.6.0-1cb0d36b39
_repo=OpenSSL
_name=openssl
_dir="$ROOTDIR/$_name-$PLATFORM-$ARCH-$_version"

_download="https://github.com/crueter-ci/$_repo/releases/download/v$_version/$_name-$PLATFORM-$ARCH-$_version.tar.zst"
_artifact="$_name-$PLATFORM-$ARCH-$_version.tar.zst"

if [ ! -d "$_dir" ]; then
	echo "-- Downloading $_repo..."
	echo "$_download"
	[ -f "$_artifact" ] || curl -L "$_download" -o "$_artifact"
	mkdir -p "$_dir"
	$TAR xf "$_artifact" -C "$_dir"
	rm -f "$_dir"/CMakeLists.txt
	find "$_dir" -name "*.dll*" -type f -exec rm {} \;
fi

find "$_dir" -name "*.pc" | while read -r pc; do
	echo "-- * Patching pc file $pc"
	sed "s|^prefix=\/.*$|prefix=$_dir|g" "$pc" > "$pc".tmp
	mv "$pc".tmp "$pc"
done

export OPENSSL_DIR="$_dir"

