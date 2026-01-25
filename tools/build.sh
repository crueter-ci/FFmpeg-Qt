#!/bin/bash -e

# shellcheck disable=SC1091

set -e

if [ "$PLATFORM" = windows ]; then
	# gets cl.exe and link.exe into the PATH
	# shellcheck disable=SC2154
	CLPATH=$(cygpath -u "$VCToolsInstallDir\\bin\\Host${VSCMD_ARG_HOST_ARCH}\\${VSCMD_ARG_TGT_ARCH}")

	# also have to implant windows sdk into path
	# thanks ffmpeg......
	# shellcheck disable=SC2154
	SDKPATH=$(cygpath -u "$WindowsSdkVerBinPath/$VSCMD_ARG_HOST_ARCH")

	# also add /bin so find exists
	# and msys2 stuff for misc tools like make etc.
 	export PATH="$CLPATH:$SDKPATH:/bin:$PATH:/$MSYSTEM/bin"

	echo "-- MSVC path: $CLPATH"
	echo "-- SDK path: $SDKPATH"

	[ -d "$CLPATH" ] || { echo "-- MSVC Path does not exist."; exit 1; }
	[ -d "$SDKPATH" ] || { echo "-- SDK Path does not exist."; exit 1; }
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
	. deps/pkgconf.sh
	. deps/nasm.sh
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
fi

. deps/openssl.sh
! unix  || . deps/libva.sh
! need_vk || . deps/vulkan.sh
! need_vk || . deps/nvcodec.sh

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

# TODO
if [ "${CCACHE:-true}" = true ] && command -v ccache >/dev/null 2>&1; then
	_ccache="$(which ccache)"
	CC="$_ccache $CC"
	CXX="$_ccache $CXX"

	echo "-- Using ccache at ${_ccache}"
fi

PLATFORM_FLAGS+=(
	--cc="$CC"
	--cxx="$CXX"
)

## Build Functions ##

# cmake
configure() {
	echo "-- Configuring $PRETTY_NAME..."

	printf -- "-- * OpenSSL pkgconfig: "
    pkg-config --cflags --libs openssl

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
			--extra-cflags="-I$VULKAN_DIR/include"
			--extra-cflags="-I$FFNVCODEC_HEADERS_DIR/include")

		arm64 || CONFIGURE_FLAGS+=("${NVDEC_ACCEL[@]}")
	fi

    echo "-- * Package config path: $PKG_CONFIG_PATH"

	# Please stop using assembly.
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

	./configure "${CONFIGURE_FLAGS[@]}" --prefix="$OUT_DIR"
}

# TODO: port this to regular ffmpeg build
build() {
	if msvc; then
		# Windows will kill itself if you try to use \\ instead of \\\\ for paths. awesome
		# remember folks, JUST USE CMAKE. It's really not that hard!
		sed -i 's|gsub(/\\\\|gsub(/\\\\\\\\|g' ffbuild/*.mak

		# windows also has a line limit of 8191 characters in the shell
		# FFmpeg in their infinite wisdom chose to output every single object file in libavcodec at once
		# in library.mak. So we have to fix their crap again.

		# shellcheck disable=SC2016
		sed -i 's/\$(Q)echo \$\^ > \$@\.objs/\$(file >\$@.objs,$(OBJS) $(STLIBOBJS))/' ffbuild/library.mak
	fi

    echo "-- Building $PRETTY_NAME..."
    export CL=" /MP"

	$MAKE -j"$(num_procs)"
}

## Packaging ##
copy_build_artifacts() {
    echo "-- Copying artifacts..."
    mkdir -p "$OUT_DIR"

	if solaris; then
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
