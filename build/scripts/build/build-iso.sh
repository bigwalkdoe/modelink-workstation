#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Modelink Workstation ISO Builder
# ============================================================
# Usage: build-iso.sh [--edition <edition>] [--output <dir>]
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

# Defaults
EDITION="${1:-developer}"
OUTPUT_DIR="/tmp/modelink-iso"
CHROOT_DIR="${OUTPUT_DIR}/chroot"
IMAGE_DIR="${OUTPUT_DIR}/image"
UBUNTU_CODENAME="noble"  # Ubuntu 24.04
UBUNTU_VERSION="24.04"
ISO_LABEL="MODELINK_${EDITION}_$(date +%Y%m%d)"
ARCH="amd64"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --edition) EDITION="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

EDITION_DIR="${BUILD_DIR}/packages/editions/${EDITION}"
CHROOT_SCRIPTS="${BUILD_DIR}/scripts/chroot"
POST_SCRIPTS="${BUILD_DIR}/scripts/post-install"
BRANDING_DIR="${BUILD_DIR}/branding"
CONFIG_DIR="${BUILD_DIR}/config"

log()  { echo "[+] $*"; }
err()  { echo "[!] $*" >&2; exit 1; }

# ---- Sanity checks ----
command -v debootstrap >/dev/null 2>&1 || err "debootstrap not found"
command -v mksquashfs >/dev/null 2>&1 || err "squashfs-tools not found"
command -v xorriso >/dev/null 2>&1 || err "xorriso not found"

[ -d "$EDITION_DIR" ] || err "Edition '${EDITION}' not found at ${EDITION_DIR}"

# ---- Clean ----
log "Cleaning previous build artifacts..."
rm -rf "$CHROOT_DIR" "$IMAGE_DIR"
mkdir -p "$CHROOT_DIR" "$IMAGE_DIR" "${OUTPUT_DIR}/iso"

# ---- Stage 1: Base system with debootstrap ----
log "Bootstrapping Ubuntu ${UBUNTU_VERSION} base system..."

debootstrap --arch="$ARCH" \
  --include=ubuntu-minimal,ubuntu-standard \
  "$UBUNTU_CODENAME" "$CHROOT_DIR" \
  http://archive.ubuntu.com/ubuntu/

# ---- Stage 2: Chroot setup ----
log "Configuring chroot environment..."

# Mount necessary filesystems
mount --bind /dev "$CHROOT_DIR/dev"
mount --bind /proc "$CHROOT_DIR/proc"
mount --bind /sys "$CHROOT_DIR/sys"
trap 'umount -l "$CHROOT_DIR/dev" 2>/dev/null; umount -l "$CHROOT_DIR/proc" 2>/dev/null; umount -l "$CHROOT_DIR/sys" 2>/dev/null' EXIT

# Copy DNS config
cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"

chroot "$CHROOT_DIR" /bin/bash <<'CHROOT'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export TZ=UTC

# Set up locale
apt-get update
apt-get install -y locales
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Add multiverse and universe repos
apt-get install -y software-properties-common
add-apt-repository -y universe
add-apt-repository -y multiverse
apt-get update
CHROOT

# ---- Stage 3: Package installation ----
log "Installing packages for ${EDITION} edition..."

# Read and merge all package lists for this edition
PKG_FILES=()
PKG_FILES+=("${BUILD_DIR}/packages/core.txt")

# Edition-specific base
case "$EDITION" in
  core) ;;
  developer) PKG_FILES+=("${BUILD_DIR}/packages/developer.txt") ;;
  ai) PKG_FILES+=("${BUILD_DIR}/packages/developer.txt" "${BUILD_DIR}/packages/ai.txt") ;;
  security) PKG_FILES+=("${BUILD_DIR}/packages/security.txt") ;;
  enterprise)
    PKG_FILES+=(
      "${BUILD_DIR}/packages/developer.txt"
      "${BUILD_DIR}/packages/ai.txt"
      "${BUILD_DIR}/packages/security.txt"
      "${BUILD_DIR}/packages/enterprise.txt"
    )
    ;;
esac

# Deduplicate and install
PACKAGES=$(cat "${PKG_FILES[@]}" | grep -v '^\s*#' | grep -v '^\s*$' | sort -u | tr '\n' ' ')

if [ -n "$PACKAGES" ]; then
  chroot "$CHROOT_DIR" /bin/bash <<CHROOT
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get install -y $PACKAGES
CHROOT
fi

# ---- Stage 4: Run edition-specific chroot scripts ----
if [ -d "$CHROOT_SCRIPTS" ]; then
  for script in "$CHROOT_SCRIPTS"/*.sh; do
    [ -f "$script" ] || continue
    log "Running chroot script: $(basename "$script")"
    cp "$script" "$CHROOT_DIR/tmp/setup.sh"
    chroot "$CHROOT_DIR" /bin/bash /tmp/setup.sh
    rm -f "$CHROOT_DIR/tmp/setup.sh"
  done
fi

# ---- Stage 5: Apply branding ----
log "Applying Modelink branding..."

# Copy wallpapers
if [ -d "${BRANDING_DIR}/wallpapers" ]; then
  mkdir -p "$CHROOT_DIR/usr/share/wallpapers/modelink"
  cp -r "${BRANDING_DIR}/wallpapers/"* "$CHROOT_DIR/usr/share/wallpapers/modelink/" 2>/dev/null || true
fi

# Plymouth theme
if [ -d "${BRANDING_DIR}/plymouth" ]; then
  mkdir -p "$CHROOT_DIR/usr/share/plymouth/themes/modelink"
  cp -r "${BRANDING_DIR}/plymouth/"* "$CHROOT_DIR/usr/share/plymouth/themes/modelink/" 2>/dev/null || true
  chroot "$CHROOT_DIR" update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/modelink/modelink.plymouth 100 2>/dev/null || true
fi

# SDDM theme
if [ -d "${BRANDING_DIR}/sddm" ]; then
  mkdir -p "$CHROOT_DIR/usr/share/sddm/themes/modelink"
  cp -r "${BRANDING_DIR}/sddm/"* "$CHROOT_DIR/usr/share/sddm/themes/modelink/" 2>/dev/null || true
fi

# GRUB branding
if [ -d "${BRANDING_DIR}/grub" ]; then
  cp -r "${BRANDING_DIR}/grub/"* "$CHROOT_DIR/usr/share/grub/" 2>/dev/null || true
fi

# ---- Stage 6: Apply configuration ----
log "Applying system configuration..."

chroot "$CHROOT_DIR" /bin/bash <<'CHROOT'
set -euo pipefail

# Set hostname
echo "modelink" > /etc/hostname

# Enable services
systemctl enable sddm 2>/dev/null || true
systemctl enable ufw 2>/dev/null || true
systemctl enable fail2ban 2>/dev/null || true
systemctl enable ssh 2>/dev/null || true

# Configure UFW defaults
ufw default deny incoming 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
CHROOT

# ---- Stage 7: Create squashfs ----
log "Creating squashfs filesystem..."

# Clean up chroot
rm -f "$CHROOT_DIR/etc/resolv.conf"
umount -l "$CHROOT_DIR/dev" 2>/dev/null || true
umount -l "$CHROOT_DIR/proc" 2>/dev/null || true
umount -l "$CHROOT_DIR/sys" 2>/dev/null || true

SQUASHFS_FILE="${IMAGE_DIR}/casper/filesystem.squashfs"
mkdir -p "$(dirname "$SQUASHFS_FILE")"
mksquashfs "$CHROOT_DIR" "$SQUASHFS_FILE" -comp xz -b 1M -noappend

# ---- Stage 8: Build ISO ----
log "Building ISO..."

# Kernel and initrd
cp "$CHROOT_DIR/boot/vmlinuz-"* "${IMAGE_DIR}/casper/vmlinuz"
cp "$CHROOT_DIR/boot/initrd.img-"* "${IMAGE_DIR}/casper/initrd"

# Create ISO
xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "$ISO_LABEL" \
  -eltorito-boot boot/grub/bios.img \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-catalog boot/grub/boot.cat \
  -grub2-boot-info \
  -grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
  -efi-boot boot/grub/efi.img \
  -efi-boot-part --efi-boot-image \
  -o "${OUTPUT_DIR}/modelink-${EDITION}-${UBUNTU_VERSION}-$(date +%Y%m%d).iso" \
  "$IMAGE_DIR"

log "ISO built successfully:"
ls -lh "${OUTPUT_DIR}"/modelink-*.iso

# Generate checksums
cd "$OUTPUT_DIR"
sha256sum modelink-*.iso > "modelink-${EDITION}-${UBUNTU_VERSION}-$(date +%Y%m%d).sha256"
echo "SHA256 checksum: $(cat "modelink-${EDITION}-${UBUNTU_VERSION}-$(date +%Y%m%d).sha256")"
