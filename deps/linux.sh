#!/bin/sh -ex

sudo apt-get update

sudo apt-get install -y \
    nasm \
    cmake \
    build-essential \
    git \
    unzip \
    gcc \
    libdrm-dev \
    ninja-build \
	libx11-xcb-dev \
	libxrandr-dev \
	ninja-build \
	libvulkan-dev \
	libffmpeg-nvenc-dev

# THANK YOU UBUNTU
git clone https://github.com/KhronosGroup/Vulkan-Headers.git
cd Vulkan-Headers

cmake -S . -B build
sudo cmake --install build --prefix /usr
