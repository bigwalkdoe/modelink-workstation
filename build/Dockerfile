FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get install -y \
    debootstrap \
    xorriso \
    isolinux \
    syslinux-utils \
    squashfs-tools \
    genisoimage \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-ia32-bin \
    mtools \
    dosfstools \
    wget \
    ca-certificates \
    curl \
    git \
    make \
    gpg \
    gpg-agent \
    rsync \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . /build

ENTRYPOINT ["/build/build/scripts/build/build-iso.sh"]
