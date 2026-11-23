#!/bin/sh -e

_version=4.0.1-1795399509-b64f68a94e
_repo=OpenSSL-Qt
_name=openssl
_TAR=tar
_dir="$ROOTDIR/$_name-$PLATFORM-$ARCH-$_version"

_download="https://github.com/crueter-ci/$_repo/releases/download/$_version/$_name-$PLATFORM-$ARCH-$_version.tar.zst"
_artifact="$_name-$PLATFORM-$ARCH-$_version.tar.zst"

if [ ! -d "$_dir" ]; then
	_group "Downloading $_repo"
	echo "URL: $_download"
	[ -f "$_artifact" ] || curl -L "$_download" -o "$_artifact"
	mkdir -p "$_dir"
	$_TAR xf "$_artifact" -C "$_dir"
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

if [ -z "$PKG_CONFIG_PATH" ]; then
	export PKG_CONFIG_PATH="$_dir/lib/pkgconfig"
else
	export PKG_CONFIG_PATH="$_dir/lib/pkgconfig:$PKG_CONFIG_PATH"
fi
echo "PKG CONFIG PATH: $PKG_CONFIG_PATH"
pkg-config --cflags --libs openssl

_end
