#!/bin/sh -ex

sudo apt-get update

sudo apt-get install -y \
    nasm \
    cmake \
    build-essential \
    git \
    unzip \
    gcc \
    libffmpeg-nvenc-dev \
    libvulkan-dev \
    libdrm-dev \
    ninja-build