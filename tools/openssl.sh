#!/bin/sh -e

export OPENSSL_VERSION=3.6.0-1cb0d36b39
export OPENSSL_DIR="$ROOTDIR/openssl-$PLATFORM-$ARCH-$VERSION"

_download="https://github.com/crueter-ci/OpenSSL/releases/download/v$OPENSSL_VERSION/openssl-$PLATFORM-$ARCH-$OPENSSL_VERSION.tar.zst"
_artifact="openssl-$PLATFORM-$ARCH-$OPENSSL_VERSION.tar.zst"

download_openssl() {
	echo "-- Downloading OpenSSL..."
	if [ ! -d "$OPENSSL_DIR" ]; then
		[ -f "$_artifact" ] || curl -L "$_download" -o "$_artifact"
		mkdir -p "$OPENSSL_DIR"
		$TAR xf "$_artifact" -C "$OPENSSL_DIR"
		rm -f "$OPENSSL_DIR"/CMakeLists.txt "$OPENSSL_DIR"/lib/*.so* "$OPENSSL_DIR"/bin/*.dll*
	fi

	find "$OPENSSL_DIR" -name "*.pc" | while read -r pc; do
		echo "-- * Patching pc file $pc"
		sed "s|^prefix=\/.*$|prefix=$OPENSSL_DIR|g" "$pc" > "$pc".tmp
		mv "$pc".tmp "$pc"
	done

	echo "-- Extracted contents:"
	find "$OPENSSL_DIR" -type f -printf "-- * %p\n"
}
