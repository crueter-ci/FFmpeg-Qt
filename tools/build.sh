#!/bin/bash -e

# shellcheck disable=SC1091

set -e

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
 	# shellcheck disable=SC2154
	# gets cl.exe and link.exe into the PATH
	CLPATH=$(cygpath -u "$VCToolsInstallDir\\bin\\Host${VSCMD_ARG_HOST_ARCH}\\${VSCMD_ARG_TGT_ARCH}")
 	export PATH="$CLPATH:$PATH"
	echo "$CLPATH"
	ls "$CLPATH"
	cl.exe
fi

. deps/openssl.sh
! unix  || . deps/libva.sh
! need_vk || . deps/vulkan.sh
! need_vk || . deps/nvcodec.sh

# shellcheck disable=SC1091
msvc && . windows/prepare.sh

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
	freebsd)
		PLATFORM_FLAGS=(
			"${VAAPI_ACCEL[@]}"
        )
		;;
	openbsd)
		PLATFORM_FLAGS=(
			--extra-cflags="-I/usr/local/include"
        )
		;;
	solaris)
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
			--extra-cflags="-I\"$VULKAN_SDK/include\""
		)

		PLATFORM_FLAGS+=(--extra-cflags="-I\"$FFNVCODEC_DIR/include\"")
		;;
	mingw)
		PLATFORM_FLAGS=(
			"${DXVA_ACCEL[@]}"
			"${D3D_ACCEL[@]}"
		)
		;;
esac

PLATFORM_FLAGS+=(
	--cc="$CC"
	--cxx="$CXX"
)

## Build Functions ##

# cmake
configure() {
	echo "-- Configuring $PRETTY_NAME..."

	msvc && [ "$ARCH" = amd64 ] && export PKG_CONFIG_PATH="$FFNVCODEC_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
	export PKG_CONFIG_PATH="$OPENSSL_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"

    if [ ! -d "$OPENSSL_DIR"/lib/pkgconfig ]; then
        echo "-- ! OpenSSL dir $OPENSSL_DIR does not contain lib/pkgconfig."
        exit 1
    fi

	printf -- "-- * OpenSSL pkgconfig: "
    if ! pkg-config --cflags --libs openssl; then
		echo "Not found"
        echo "-- ! OpenSSL pkgconfig failed."
        exit 1
    fi

	# libva
	if unix; then
		export PKG_CONFIG_PATH="$LIBVA_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
		printf -- "-- * libva pkg-config: "
		pkg-config --cflags --libs libva
	fi

	# vk + nvcodec
	if need_vk; then
		export PKG_CONFIG_PATH="$FFNVCODEC_HEADERS_DIR/lib/pkgconfig:$VULKAN_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
		printf -- "-- * vulkan pkg-config: "
		pkg-config --cflags --libs vulkan
		printf -- "-- * ffnvcodec pkg-config: "
		pkg-config --cflags --libs ffnvcodec
		CONFIGURE_FLAGS+=(
			"${VULKAN_ACCEL[@]}"
			"${NVDEC_ACCEL[@]}"
			--extra-cflags="-I$VULKAN_DIR/include"
		)
	fi

    echo "-- * Package config path: $PKG_CONFIG_PATH"

	# FFmpeg's x86_64 assembly on Android sucks
	# Remember folks: this is why you use C :)
	android && [ "$ARCH" = "x86_64" ] && CONFIGURE_FLAGS+=(--disable-asm)

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

	./configure "${CONFIGURE_FLAGS[@]}" --prefix="$OUT_DIR"
}

build() {
    echo "-- Building $PRETTY_NAME..."
    export CL=" /MP"

    $MAKE -j"$(num_procs)"
}

## Packaging ##
copy_build_artifacts() {
    echo "-- Copying artifacts..."
    mkdir -p "$OUT_DIR"

	if [ "$PLATFORM" = "solaris" ]; then
		mkdir -p "$OUT_DIR"/lib
		find . -name "*.a" -exec cp {} "$OUT_DIR"/lib \;
		ls "$OUT_DIR"/lib
		echo
	    $MAKE install-headers INSTALL="/usr/bin/install -C"
	else
    	$MAKE install
	fi
}


## Cleanup ##
rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# ## Download + Extract ##
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
