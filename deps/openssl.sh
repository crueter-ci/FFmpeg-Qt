#!/bin/sh -e

_version=3.6.0-1cb0d36b39
_repo=OpenSSL-Qt
_name=openssl
_dir="$ROOTDIR/$_name-$PLATFORM-$ARCH-$_version"

_download="https://github.com/crueter-ci/$_repo/releases/download/v$_version/$_name-$PLATFORM-$ARCH-$_version.tar.zst"
_artifact="$_name-$PLATFORM-$ARCH-$_version.tar.zst"

if [ ! -d "$_dir" ]; then
	_group "Downloading $_repo"
	echo "URL: $_download"
	[ -f "$_artifact" ] || curl -L "$_download" -o "$_artifact"
	mkdir -p "$_dir"
	$TAR xf "$_artifact" -C "$_dir"
	rm -f "$_dir"/CMakeLists.txt
	/usr/bin/find "$_dir" -name "*.dll*" -type f -exec rm {} \;

	/usr/bin/find "$_dir" -name "*.pc" | while read -r pc; do
		echo "-- * Patching pc file $pc"
		sed "s|^prefix=\/.*$|prefix=$_dir|g" "$pc" > "$pc".tmp
		mv "$pc".tmp "$pc"
	done
fi

if [ ! -d "$_dir"/lib/pkgconfig ]; then
	echo "-- ! OpenSSL dir $_dir does not contain lib/pkgconfig."
	exit 1
fi

if [ ! -f "$_dir"/lib/pkgconfig/openssl.pc ]; then
	echo "-- ! OpenSSL pkgconfig dir $_dir/lib/pkgconfig does not contain openssl.pc."
	exit 1
fi

export PKG_CONFIG_PATH="$_dir/lib/pkgconfig"
echo "PKG CONFIG PATH: $PKG_CONFIG_PATH"
pkg-config --cflags --libs openssl

_end
