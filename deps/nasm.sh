#!/bin/sh -e

# TODO: does arm need this?
_ver=3.01
_url=https://nasm.us/pub/nasm/releasebuilds/$_ver/win64/nasm-$_ver-win64.zip

if ! command -v nasm >/dev/null 2>&1; then
	echo "-- Installing nasm..."
	mkdir -p /usr/local/bin
	curl -L "$_url" -o nasm.zip
	unzip nasm.zip
	mv nasm*/nasm.exe /usr/local/bin/nasm.exe
	rm -rf nasm*
fi