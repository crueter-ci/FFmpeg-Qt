#!/bin/sh -ex

# This is only used for the MSVC target

export PATH="/usr/local/bin:$PATH"

# TODO: does arm need this?
echo "-- Installing nasm..."

NASM_VER=3.01

if ! command -v nasm 2>/dev/null; then
	mkdir -p /usr/local/bin
	curl -L https://nasm.us/pub/nasm/releasebuilds/$NASM_VER/win64/nasm-$NASM_VER-win64.zip -o nasm.zip
	unzip nasm.zip
	mv nasm*/nasm.exe /usr/local/bin/nasm.exe
	rm -rf nasm*
fi

echo "-- Installing gas-preprocessor..."

if ! command -v gas-preprocessor 2>/dev/null; then
	mkdir -p /usr/local/bin
	curl -L https://github.com/FFmpeg/gas-preprocessor/raw/refs/heads/master/gas-preprocessor.pl -o gas-preprocessor.pl

	# FUCK
	cp gas-preprocessor.pl /usr/local/bin
	cp gas-preprocessor.pl /usr/bin
	cp gas-preprocessor.pl /usr/local/bin/gas-preprocessor
	cp gas-preprocessor.pl /usr/bin/gas-preprocessor

	chmod a+x /usr/bin/gas-preprocessor*
	chmod a+x /usr/local/bin/gas-preprocessor*

	gas-preprocessor -help
fi
