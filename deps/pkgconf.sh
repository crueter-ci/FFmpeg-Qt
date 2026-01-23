#!/bin/sh -e

_version=2.5.1
_repo=pkgconf
_name=pkgconf
_dir="$ROOTDIR/$_name-$ARCH-$_version"

_download="https://github.com/crueter-ci/$_repo/releases/download/v$_version/$_name-$ARCH.exe"
_artifact="pkg-config.exe"

if ! command -v pkg-config >/dev/null 2>&1; then
	[ -d "$_dir" ] || mkdir "$_dir"

	[ -f "$_dir/$_artifact" ] || { echo "-- Downloading pkgconf..."; curl -L "$_download" -o "$_dir/$_artifact"; }

	export PATH="$PATH:$_dir"
fi