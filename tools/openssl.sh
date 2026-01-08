#!/bin/sh -e

export OPENSSL_VERSION=3.6.0-1cb0d36b39
export OPENSSL_DIR="$ROOTDIR"/openssl

_download="https://github.com/crueter-ci/OpenSSL/releases/download/v$OPENSSL_VERSION/openssl-$PLATFORM-$ARCH-$OPENSSL_VERSION.tar.zst"
_artifact="openssl-$PLATFORM-$ARCH-$OPENSSL_VERSION.tar.zst"

download_openssl() {
	if [ ! -d "$OPENSSL_DIR" ]; then
		[ -f "$_artifact" ] || curl -L "$_download" -o "$_artifact"
		mkdir -p "$OPENSSL_DIR"
		tar xf "$_artifact" -C "$OPENSSL_DIR"
		rm -f "$OPENSSL_DIR"/CMakeLists.txt "$OPENSSL_DIR"/lib/*.so* "$OPENSSL_DIR"/bin/*.dll*
	fi

	find "$OPENSSL_DIR" -name "*.pc" | while read -r pc; do
		sed "s|prefix=\/$|prefix=$OPENSSL_DIR|g" "$pc" > "$pc".tmp
		mv "$pc".tmp "$pc"
	done
}
