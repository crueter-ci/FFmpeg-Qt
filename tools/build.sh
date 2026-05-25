#!/bin/bash -e

# shellcheck disable=SC1091

set -e

if [ "$PLATFORM" = windows ]; then
	# shellcheck disable=SC2154
	TOOLSDIR=$(cygpath -u "$VCToolsInstallDir")
	export PATH="${TOOLSDIR}/bin/Host${VSCMD_ARG_HOST_ARCH}/${VSCMD_ARG_TGT_ARCH}/:$PATH"

	VULKAN_SDK=$(cygpath -u "${VULKAN_SDK:?}")
	FFNVCODEC_DIR=$(cygpath -u "${FFNVCODEC_DIR:?}")
fi

. tools/common.sh

## Buildtime/Input Variables ##

DEFAULT_ARCH=amd64
if android; then
	DEFAULT_ARCH=aarch64
	: "${ANDROID_NDK_ROOT:?-- You must supply the ANDROID_NDK_ROOT environment variable.}"
	: "${ANDROID_API:=23}"
	android_paths
fi

: "${ARCH:=$DEFAULT_ARCH}"
: "${BUILD_DIR:=build}"

mkdir -p "$BUILD_DIR"

if android; then
	CC="${ARCH}"-linux-android"${ANDROID_API}"-clang
	CXX="${ARCH}"-linux-android"${ANDROID_API}"-clang++
fi

## Platform Stuff ##

need_vk() {
	! android && ! macos
}

if msvc; then
	_group "MSVC Setup"
	[ "$ARCH" = amd64 ] || . deps/gas.sh

	printf -- "-- cl: "
	command -v cl

	printf -- "-- mt: "
	command -v mt

	printf -- "-- rc: "
	command -v rc

	printf -- "-- link: "
	command -v link

	printf -- "-- pkg-config: "
	command -v pkg-config

	printf -- "-- cmake: "
	command -v cmake

	printf -- "-- ninja: "
	command -v ninja
	_end
fi

. deps/openssl.sh
if linux; then . deps/libva.sh; fi

VULKAN_ACCEL=(--enable-vulkan --enable-hwaccel={h264,vp9}_vulkan)
NVDEC_ACCEL=(--enable-cuvid
            --enable-ffnvcodec
            --enable-nvdec
			--enable-hwaccel={h264,vp8,vp8}_nvdec)
VAAPI_ACCEL=(--enable-vaapi --enable-hwaccel={h264,vp8,vp9}_vaapi)
DXVA_ACCEL=(--enable-dxva2 --enable-hwaccel={h264,vp9}_dxva2)
D3D_ACCEL=(--enable-d3d11va --enable-hwaccel={h264,vp9}_d3d11va{,2} --enable-d3d12va --enable-hwaccel={h264,vp9}_d3d12va)
MEDIACODEC_ACCEL=(--enable-mediacodec
				  --enable-jni
				  --enable-decoder={h264,vp8,vp9}_mediacodec)
VIDEOTOOLBOX_ACCEL=(--enable-videotoolbox --enable-hwaccel={h264,vp9}_videotoolbox)

case "$PLATFORM" in
	linux)
		PLATFORM_FLAGS=(
			"${VAAPI_ACCEL[@]}"
			--extra-cflags="-Og -g -fno-lto -fno-strict-aliasing -fno-omit-frame-pointer"
        )
		;;
	android)
		PLATFORM_FLAGS=(
			"${MEDIACODEC_ACCEL[@]}"

			--extra-ldflags="-Wl,-z,max-page-size=16384,--hash-style=both"

			--enable-cross-compile
			--target-os=android
			--arch="$ARCH"
		)
		;;
	macos)
		PLATFORM_FLAGS=(
			"${VIDEOTOOLBOX_ACCEL[@]}"
            --disable-iconv

			--extra-cflags="-mmacosx-version-min=11.0 -arch arm64 -arch x86_64"
			--extra-ldflags="-mmacosx-version-min=11.0 -arch arm64 -arch x86_64"
			--disable-asm
        )
		;;
	windows)
		PLATFORM_FLAGS=(
			"${DXVA_ACCEL[@]}"
			"${D3D_ACCEL[@]}"

			--toolchain=msvc
			--arch="$ARCH"
			--target-os=win64
			# --extra-cflags="-I\"$VULKAN_SDK/include\""
		)
		;;
	mingw)
		PLATFORM_FLAGS=(
			"${DXVA_ACCEL[@]}"
			"${D3D_ACCEL[@]}"
		)
		;;
esac

# TODO: sccache?
if ! msvc && [ "${CCACHE:-true}" = true ] && command -v ccache >/dev/null 2>&1; then
	ccache="$(which ccache)"
	CC="$ccache $CC"
	CXX="$ccache $CXX"

	echo "-- Using ccache at ${ccache}"
fi

PLATFORM_FLAGS+=(
	--cc="$CC"
	--cxx="$CXX")

## Build Functions ##

# cmake
configure() {
	_group "Configuring $PRETTY_NAME"

	printf -- "-- * OpenSSL pkgconfig: "
    pkg-config --cflags --libs openssl

	# libva
	if linux; then
		export PKG_CONFIG_PATH="$LIBVA_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
		printf -- "-- * libva pkg-config: "
		pkg-config --cflags --libs libva
	fi

	# vk + nvcodec
	if need_vk; then
		export PKG_CONFIG_PATH="$FFNVCODEC_DIR/lib/pkgconfig:$VULKAN_SDK/lib/pkgconfig:$PKG_CONFIG_PATH"
    	echo "-- * (vk) Package config path: $PKG_CONFIG_PATH"

		printf -- "-- * vulkan pkg-config: "
		pkg-config --cflags --libs vulkan
		printf -- "-- * ffnvcodec pkg-config: "
		pkg-config --cflags --libs ffnvcodec

		# CONFIGURE_FLAGS+=(
		# 	"${VULKAN_ACCEL[@]}"
		# 	--extra-cflags="-I$FFNVCODEC_DIR/include")

		CONFIGURE_FLAGS+=("${VULKAN_ACCEL[@]}")

		arm64 || CONFIGURE_FLAGS+=("${NVDEC_ACCEL[@]}")
	fi

    echo "-- * Package config path: $PKG_CONFIG_PATH"

	if android && amd64; then
		CONFIGURE_FLAGS+=(--disable-asm)
	fi

	# shellcheck disable=SC2054
	CONFIGURE_FLAGS+=(
        --disable-doc
        --disable-programs
        --enable-swresample
		--enable-network
		--enable-openssl
		--enable-static
		--disable-shared
		--enable-pic
		--enable-protocol=file,http,https,tcp,udp,rtp
		--pkg-config-flags="--static"
        --prefix=/
        "${PLATFORM_FLAGS[@]}"
	)

	echo "-- * Configure flags: ${CONFIGURE_FLAGS[*]}"

	if windows; then
		cfg="$(cygpath -w "$PWD"/ffbuild/config.log)"
	else
		cfg="$PWD/ffbuild/config.log"
	fi

	echo "CONFIG_LOG=$cfg" >> "$GITHUB_ENV"
	./configure "${CONFIGURE_FLAGS[@]}" --prefix="$OUT_DIR"

	_end
}

# TODO: port this to regular ffmpeg build
build() {
	_group "Building $PRETTY_NAME"
	if msvc; then
		# # For some reason configure tries to make cl.exe the HOSTLD
		# sed -i 's|^HOSTLD=.*|HOSTLD=./compat/windows/mslink|' ffbuild/config.mak
		# sed -i 's|^HOSTLD_O=.*|HOSTLD_O=-out:$@|' ffbuild/config.mak

		# shellcheck disable=SC2016
		sed -i 's/\$(Q)echo \$\^ > \$@\.objs/\$(file >\$@.objs,\$^)/' ffbuild/library.mak

		# backslash greatness
		sed -i 's/; gsub(\/\\\\\/, "\/"); /; /g' ffbuild/config.mak
		sed -i 's/; gsub(\/\\\\\/, "\/")/; /g' ffbuild/config.mak
	fi

	export CL=" /MP"

	$MAKE -j"$(num_procs)"
	_end
}

## Packaging ##
copy_build_artifacts() {
    _group "Copying artifacts"
    mkdir -p "$OUT_DIR"

	$MAKE install
	_end
}

## Cleanup ##
rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

## Download + Extract ##
download
cd "$BUILD_DIR"
extract

## Configure ##
cd "$DIRECTORY"
configure

## Build ##
build
copy_build_artifacts

## Package ##
package

echo "-- Done! Artifacts are in $ROOTDIR/artifacts, raw lib/include data is in $OUT_DIR"
