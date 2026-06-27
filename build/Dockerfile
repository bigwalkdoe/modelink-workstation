FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install build dependencies
RUN apt-get update && apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-common \
    syslinux-efi \
    syslinux-utils \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-ia32-bin \
    grub-efi-amd64-signed \
    shim-signed \
    mtools \
    dosfstools \
    wget ca-certificates curl \
    git make \
    gpg gpg-agent \
    rsync \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . /build

ENTRYPOINT ["/build/build/scripts/build/build-iso.sh"]
CMD ["--edition", "developer"]
