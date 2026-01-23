#!/bin/sh -e

_url=https://github.com/FFmpeg/gas-preprocessor/raw/refs/heads/master/gas-preprocessor.pl

export PATH="/usr/local/bin:$PATH"

if ! command -v gas-preprocessor 2>/dev/null; then
	echo "-- Installing gas-preprocessor..."

	mkdir -p /usr/local/bin
	curl -L "$_url" -o /usr/local/bin/gas-preprocessor
	chmod a+x /usr/local/bin/gas-preprocessor
fi
