#!/bin/sh -ex

# This is only used for the MSVC target

export PATH="/usr/local/bin:$PATH"

# TODO: does arm need this?
NASM_VER=3.01

if ! command -v nasm 2>/dev/null; then
	echo "-- Installing nasm..."
	mkdir -p /usr/local/bin
	curl -L https://nasm.us/pub/nasm/releasebuilds/$NASM_VER/win64/nasm-$NASM_VER-win64.zip -o nasm.zip
	unzip nasm.zip
	mv nasm*/nasm.exe /usr/local/bin/nasm.exe
	rm -rf nasm*
fi

if ! command -v gas-preprocessor 2>/dev/null; then
	echo "-- Installing gas-preprocessor..."

	mkdir -p /usr/local/bin
	curl -L https://github.com/FFmpeg/gas-preprocessor/raw/refs/heads/master/gas-preprocessor.pl -o /usr/local/bin/gas-preprocessor
	chmod a+x /usr/local/bin/gas-preprocessor

	command -v gas-preprocessor
	rm gas-preprocessor
fi
