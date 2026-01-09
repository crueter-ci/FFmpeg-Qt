#!/bin/sh -ex

pacman -Syu --needed --noconfirm \
    nasm \
    cmake \
    base-devel \
    git \
    unzip \
    gcc \
    ffnvcodec-headers \
    vulkan-headers \
	libdrm \
	ninja
