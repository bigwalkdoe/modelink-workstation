#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Modelink Workstation ISO Builder
# Produces a bootable Ubuntu 24.04 LTS-based live ISO
# ============================================================
# Usage:
#   sudo ./build-iso.sh --edition developer --output /tmp/modelink-iso
#
# Requires: debootstrap, squashfs-tools, xorriso, syslinux, grub-pc-bin, grub-efi, mtools, dosfstools
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

# ---- Defaults ----
EDITION="developer"
OUTPUT_DIR="/tmp/modelink-iso"
UBUNTU_CODENAME="noble"
UBUNTU_VERSION="24.04"
ARCH="amd64"
DATE_TAG="$(date +%Y%m%d)"

# ---- Editions with additive package inheritance ----
# Each entry lists all packages/*.txt files to merge (in order)
declare -A EDITION_LAYERS
EDITION_LAYERS[core]="core"
EDITION_LAYERS[developer]="core developer"
EDITION_LAYERS[ai]="core developer ai"
EDITION_LAYERS[security]="core security"
EDITION_LAYERS[enterprise]="core developer ai security enterprise"

# ---- Parse arguments ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --edition) EDITION="$2"; shift 2 ;;
    --output)  OUTPUT_DIR="$2"; shift 2 ;;
    --codename) UBUNTU_CODENAME="$2"; shift 2 ;;
    --arch)    ARCH="$2"; shift 2 ;;
    *) echo "Usage: $0 [--edition <name>] [--output <dir>] [--codename <name>] [--arch <arch>]"; exit 1 ;;
  esac
done

# ---- Validate ----
if [[ ! -v EDITION_LAYERS[$EDITION] ]]; then
  echo "Error: Unknown edition '$EDITION'. Valid: ${!EDITION_LAYERS[*]}" >&2
  exit 1
fi

for cmd in debootstrap mksquashfs xorriso; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: $cmd not found. Install debootstrap, squashfs-tools, xorriso." >&2; exit 1; }
done

# ---- Paths ----
CHROOT_DIR="${OUTPUT_DIR}/chroot"
IMAGE_DIR="${OUTPUT_DIR}/image"
ISO_FILENAME="${OUTPUT_DIR}/modelink-${EDITION}-${UBUNTU_VERSION}-${DATE_TAG}.iso"
ISO_LABEL="MODELINK${EDITION^^}$DATE_TAG"
PKG_DIR="${BUILD_DIR}/packages"
BOOT_DIR="${BUILD_DIR}/boot"
LOGFILE="${OUTPUT_DIR}/build.log"

mkdir -p "$(dirname "$LOGFILE")"

log()  { echo "[+] $*"; echo "[+] $*" >> "$LOGFILE"; }
err()  { echo "[!] $*" >&2; echo "[!] $*" >> "$LOGFILE"; exit 1; }

# ============================================================
log "Modelink Workstation ISO Builder"
log "  Edition:  $EDITION"
log "  Output:   $OUTPUT_DIR"
log "  Label:    $ISO_LABEL"
log "  Date:     $DATE_TAG"
# ============================================================

# ---- Check disk space ----
AVAIL_GB=$(df --output=avail "$OUTPUT_DIR" | tail -1 | awk '{print int($1/1024/1024)}')
if [ "$AVAIL_GB" -lt 10 ]; then
  err "Low disk space: ${AVAIL_GB}GB available. Need at least 10GB."
fi
log "Disk space: ${AVAIL_GB}GB available"

# ---- Clean working dirs ----
log "Cleaning previous build..."
rm -rf "$CHROOT_DIR" "$IMAGE_DIR"
mkdir -p "$CHROOT_DIR" "$IMAGE_DIR"

# ============================================================
# STAGE 1 — Bootstrap base system
# ============================================================
log "Bootstrapping Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME}) base system..."

debootstrap --arch="$ARCH" \
  --include=ubuntu-minimal \
  "$UBUNTU_CODENAME" "$CHROOT_DIR" \
  http://archive.ubuntu.com/ubuntu/ \
  >> "$LOGFILE" 2>&1

# ============================================================
# STAGE 2 — Configure chroot environment
# ============================================================
log "Configuring chroot environment..."

mount --bind /dev     "$CHROOT_DIR/dev"
mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
mount --bind /proc    "$CHROOT_DIR/proc"
mount --bind /sys     "$CHROOT_DIR/sys"

cleanup_mounts() {
  umount -l "$CHROOT_DIR/dev/pts" 2>/dev/null || true
  umount -l "$CHROOT_DIR/dev"     2>/dev/null || true
  umount -l "$CHROOT_DIR/proc"    2>/dev/null || true
  umount -l "$CHROOT_DIR/sys"     2>/dev/null || true
}
trap cleanup_mounts EXIT

cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"

mkdir -p "$CHROOT_DIR/tmp"

cat > "$CHROOT_DIR/tmp/stage2-setup.sh" << 'STAGE2'
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export TZ=UTC

# Locale
apt-get update
apt-get install -y locales
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Repositories
apt-get install -y software-properties-common
add-apt-repository -y universe
add-apt-repository -y multiverse
apt-get update

# Essential live-system and boot packages
apt-get install -y --no-install-recommends \
  linux-generic \
  casper \
  live-boot \
  live-tools \
  live-config-systemd \
  ubiquity-frontend-kde \
  ubiquity \
  ubuntu-drivers-common \
  grub-pc-bin \
  grub-efi-amd64-bin \
  grub-efi-ia32-bin \
  shim-signed \
  syslinux \
  isolinux \
  syslinux-common \
  squashfs-tools \
  xorriso \
  mtools \
  dosfstools

# Firmware
apt-get install -y --no-install-recommends \
  linux-firmware \
  intel-microcode \
  amd64-microcode

# Network management for live session
apt-get install -y --no-install-recommends \
  network-manager \
  wireless-tools \
  wpasupplicant \
  avahi-daemon

# Clean up apt
apt-get clean
rm -rf /var/lib/apt/lists/*
STAGE2

chmod +x "$CHROOT_DIR/tmp/stage2-setup.sh"
chroot "$CHROOT_DIR" /bin/bash /tmp/stage2-setup.sh 2>&1 | tee -a "$LOGFILE"

# ============================================================
# STAGE 3 — Install edition packages
# ============================================================
log "Installing packages for ${EDITION} edition..."

# Merge package lists for the edition
read -ra LAYERS <<< "${EDITION_LAYERS[$EDITION]}"
PKG_FILES=()
for layer in "${LAYERS[@]}"; do
  f="${PKG_DIR}/${layer}.txt"
  [ -f "$f" ] && PKG_FILES+=("$f") || log "  Warning: ${layer}.txt not found"
done

if [ ${#PKG_FILES[@]} -eq 0 ]; then
  err "No package lists found for edition '$EDITION'"
fi

PACKAGES=$(cat "${PKG_FILES[@]}" | grep -v '^\s*#' | grep -v '^\s*$' | sort -u | tr '\n' ' ')

if [ -n "$PACKAGES" ]; then
  cat > "$CHROOT_DIR/tmp/stage3-packages.sh" << STAGE3
#!/bin/bash
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
# Best-effort install — some packages may not exist (e.g. non-apt, PPAs)
apt-get install -y $PACKAGES || {
  echo "[!] Batch install failed, retrying individually..." >&2
  FAILED=""
  for pkg in $PACKAGES; do
    apt-get install -y "\$pkg" 2>&1 | tail -2 || {
      echo "[!] Skipping unavailable: \$pkg" >&2
      FAILED="\$FAILED \$pkg"
    }
  done
  if [ -n "\$FAILED" ]; then
    echo "[!] Failed to install:\$FAILED" >&2
  fi
}
STAGE3

  chmod +x "$CHROOT_DIR/tmp/stage3-packages.sh"
  chroot "$CHROOT_DIR" /bin/bash /tmp/stage3-packages.sh 2>&1 | tee -a "$LOGFILE"
fi

# ============================================================
# STAGE 4 — Run chroot configuration scripts
# ============================================================
log "Running chroot configuration scripts..."

CHROOT_SCRIPTS="${BUILD_DIR}/scripts/chroot"
if [ -d "$CHROOT_SCRIPTS" ]; then
  for script in "$CHROOT_SCRIPTS"/*.sh; do
    [ -f "$script" ] || continue
    log "  Running $(basename "$script")..."
    cp "$script" "$CHROOT_DIR/tmp/setup.sh"
    chroot "$CHROOT_DIR" /bin/bash /tmp/setup.sh 2>&1 | tee -a "$LOGFILE"
    rm -f "$CHROOT_DIR/tmp/setup.sh"
  done
fi

# ============================================================
# STAGE 5 — Apply branding
# ============================================================
log "Applying Modelink branding..."

BRANDING_DIR="${BUILD_DIR}/branding"

# Plymouth
if [ -d "${BRANDING_DIR}/plymouth" ]; then
  mkdir -p "$CHROOT_DIR/usr/share/plymouth/themes/modelink"
  cp -r "${BRANDING_DIR}/plymouth/"* "$CHROOT_DIR/usr/share/plymouth/themes/modelink/" 2>/dev/null || true
  chroot "$CHROOT_DIR" update-alternatives --install \
    /usr/share/plymouth/themes/default.plymouth \
    default.plymouth \
    /usr/share/plymouth/themes/modelink/modelink.plymouth 100 2>/dev/null || true
fi

# SDDM
if [ -d "${BRANDING_DIR}/sddm" ]; then
  mkdir -p "$CHROOT_DIR/usr/share/sddm/themes/modelink"
  cp -r "${BRANDING_DIR}/sddm/"* "$CHROOT_DIR/usr/share/sddm/themes/modelink/" 2>/dev/null || true
fi

# GRUB theme
if [ -d "${BRANDING_DIR}/grub" ]; then
  cp -r "${BRANDING_DIR}/grub/"* "$CHROOT_DIR/usr/share/grub/" 2>/dev/null || true
fi

# Wallpapers
if [ -d "${BRANDING_DIR}/wallpapers" ]; then
  mkdir -p "$CHROOT_DIR/usr/share/wallpapers/modelink"
  cp -r "${BRANDING_DIR}/wallpapers/"* "$CHROOT_DIR/usr/share/wallpapers/modelink/" 2>/dev/null || true
fi

# ============================================================
# STAGE 6 — Apply system configuration
# ============================================================
log "Applying system configuration..."

cat > "$CHROOT_DIR/tmp/stage6-config.sh" << 'STAGE6'
#!/bin/bash
set -euo pipefail

# Hostname
echo "modelink" > /etc/hostname
echo "127.0.1.1 modelink.local modelink" >> /etc/hosts

# Enable services
systemctl enable sddm       2>/dev/null || true
systemctl enable ufw         2>/dev/null || true
systemctl enable ssh         2>/dev/null || true
systemctl enable fail2ban    2>/dev/null || true
systemctl enable cups        2>/dev/null || true
systemctl enable bluetooth   2>/dev/null || true
systemctl enable avahi-daemon 2>/dev/null || true

# Default firewall
ufw default deny incoming    2>/dev/null || true
ufw default allow outgoing   2>/dev/null || true
ufw allow ssh                2>/dev/null || true
ufw --force enable           2>/dev/null || true

# Remove machine-id so it gets regenerated on first boot
rm -f /etc/machine-id
rm -f /var/lib/dbus/machine-id
touch /etc/machine-id
STAGE6

chmod +x "$CHROOT_DIR/tmp/stage6-config.sh"
chroot "$CHROOT_DIR" /bin/bash /tmp/stage6-config.sh 2>&1 | tee -a "$LOGFILE"

# ============================================================
# STAGE 7 — Clean up chroot for ISO
# ============================================================
log "Preparing chroot for ISO packaging..."

cat > "$CHROOT_DIR/tmp/stage7-cleanup.sh" << 'STAGE7'
#!/bin/bash
set -euo pipefail

# Clean package cache
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -f /etc/resolv.conf
rm -f /var/crash/*
rm -f /var/log/*.log
rm -rf /root/.bash_history /root/.cache

# Truncate logs
for f in /var/log/*.log /var/log/*.gz; do
  [ -f "$f" ] && truncate -s 0 "$f" 2>/dev/null || true
done

# Clean up all temp files
rm -rf /tmp/*
STAGE7

chmod +x "$CHROOT_DIR/tmp/stage7-cleanup.sh"
chroot "$CHROOT_DIR" /bin/bash /tmp/stage7-cleanup.sh 2>&1 | tee -a "$LOGFILE"

# Unmount before squashing
cleanup_mounts

# ============================================================
# STAGE 8 — Create squashfs filesystem
# ============================================================
log "Creating squashfs filesystem (this may take a while)..."

SQUASHFS_FILE="${IMAGE_DIR}/casper/filesystem.squashfs"
mkdir -p "$(dirname "$SQUASHFS_FILE")"

mksquashfs "$CHROOT_DIR" "$SQUASHFS_FILE" \
  -comp xz -b 1M -noappend \
  -progress \
  >> "$LOGFILE" 2>&1

# Copy kernel and initrd
cp "$CHROOT_DIR/boot/vmlinuz-"*  "${IMAGE_DIR}/casper/vmlinuz"
cp "$CHROOT_DIR/boot/initrd.img-"* "${IMAGE_DIR}/casper/initrd"

# Write filesystem size for casper
printf "%s" "$(du -sx --block-size=1 "$CHROOT_DIR" | cut -f1)" > "${IMAGE_DIR}/casper/filesystem.size"

# Write .disk info
mkdir -p "${IMAGE_DIR}/.disk"
echo "Modelink Workstation ${UBUNTU_VERSION} LTS - ${EDITION^} - ${ARCH}" > "${IMAGE_DIR}/.disk/info"

# Remove chroot to free disk space before ISO assembly
log "Removing chroot to free disk space..."
rm -rf "$CHROOT_DIR"

# ============================================================
# STAGE 9 — Set up ISO boot configuration
# ============================================================
log "Setting up ISO boot configuration..."

# ---- ISOLINUX (BIOS boot) ----
ISOLINUX_DIR="${IMAGE_DIR}/isolinux"
mkdir -p "$ISOLINUX_DIR"

# Copy syslinux/isolinux binaries
if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
  cp /usr/lib/ISOLINUX/isolinux.bin "$ISOLINUX_DIR/"
elif [ -f /usr/lib/syslinux/isolinux.bin ]; then
  cp /usr/lib/syslinux/isolinux.bin "$ISOLINUX_DIR/"
fi

# Copy c32 modules
for f in ldlinux.c32 vesamenu.c32 libcom32.c32 libutil.c32; do
  find /usr/lib -name "$f" -exec cp {} "$ISOLINUX_DIR/" \; 2>/dev/null || true
done

# ISOLINUX config
cat > "$ISOLINUX_DIR/isolinux.cfg" << 'EOF'
default vesamenu.c32
prompt 0
timeout 100

menu title Modelink Workstation

label live
  menu label Try Modelink Workstation
  kernel /casper/vmlinuz
  append boot=casper quiet splash --- initrd=/casper/initrd

label live-install
  menu label Install Modelink Workstation
  kernel /casper/vmlinuz
  append boot=casper only-ubiquity quiet splash --- initrd=/casper/initrd

label live-check
  menu label Check CD for defects
  kernel /casper/vmlinuz
  append boot=casper integrity-check quiet splash --- initrd=/casper/initrd

label hd
  menu label Boot from first hard disk
  localboot 0x80
EOF

# A real splash.png would go here for vesamenu background

# ---- GRUB (UEFI boot) ----
GRUB_DIR="${IMAGE_DIR}/boot/grub"
mkdir -p "$GRUB_DIR"

# Write GRUB config
cat > "$GRUB_DIR/grub.cfg" << 'EOF'
set default="0"
set timeout=10

if loadfont /boot/grub/font.pf2; then
  set gfxmode=auto
  insmod gfxterm
  terminal_output gfxterm
fi

menuentry "Try Modelink Workstation" {
  linux /casper/vmlinuz boot=casper quiet splash ---
  initrd /casper/initrd
}

menuentry "Install Modelink Workstation" {
  linux /casper/vmlinuz boot=casper only-ubiquity quiet splash ---
  initrd /casper/initrd
}

menuentry "Check CD for defects" {
  linux /casper/vmlinuz boot=casper integrity-check quiet splash ---
  initrd /casper/initrd
}

menuentry "Boot from first hard disk" {
  insmod chain
  insmod ntfs
  insmod ext2
  set root=(hd0)
  chainloader +1
}
EOF

# ---- EFI boot image ----
log "Creating EFI boot image..."

EFI_IMAGE="${IMAGE_DIR}/boot/grub/efi.img"
EFI_MOUNT="/tmp/modelink-efi-mount"
rm -rf "$EFI_MOUNT"
mkdir -p "$EFI_MOUNT"

dd if=/dev/zero of="$EFI_IMAGE" bs=1M count=20 2>/dev/null
mkfs.vfat "$EFI_IMAGE" >> "$LOGFILE" 2>&1

mount -o loop "$EFI_IMAGE" "$EFI_MOUNT"

mkdir -p "$EFI_MOUNT/EFI/BOOT"
mkdir -p "$EFI_MOUNT/boot/grub"

# Install GRUB EFI binary into the FAT image (for EFI boot)
if [ -f /usr/lib/shim/shimx64.efi.signed ]; then
  cp /usr/lib/shim/shimx64.efi.signed "$EFI_MOUNT/EFI/BOOT/BOOTx64.EFI"
  cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed "$EFI_MOUNT/EFI/BOOT/grubx64.efi" 2>/dev/null || true
else
  grub-mkstandalone -O x86_64-efi -o "$EFI_MOUNT/EFI/BOOT/BOOTx64.EFI" \
    "boot/grub/grub.cfg=$GRUB_DIR/grub.cfg" >> "$LOGFILE" 2>&1
fi

# Copy bootloader from FAT image to ISO 9660 /EFI/BOOT (required by UEFI)
mkdir -p "${IMAGE_DIR}/EFI/BOOT"
cp -r "$EFI_MOUNT/EFI/BOOT"/* "${IMAGE_DIR}/EFI/BOOT/"

umount "$EFI_MOUNT"
rm -rf "$EFI_MOUNT"

# Also create a minimal boot for loopback.cfg support
cat > "${IMAGE_DIR}/boot/grub/loopback.cfg" << 'EOF'
menuentry "Modelink Workstation" {
  linux /casper/vmlinuz boot=casper quiet splash ---
  initrd /casper/initrd
}
EOF

# ============================================================
# STAGE 10 — Build the ISO
# ============================================================
# Find isohybrid MBR for hybrid ISO
ISOHYBRID_MBR=""
for p in /usr/lib/syslinux/mbr/isohybrid_mbr.bmp /usr/lib/syslinux/isohybrid_mbr.bmp; do
  [ -f "$p" ] && { ISOHYBRID_MBR="$p"; break; }
done

log "Building ISO image..."

# Prepare xorriso args (avoid quoting issues with conditional flags)
XORRISO_ARGS=(
  -r -V "$ISO_LABEL"
  -J -joliet-long
  -cache-inodes
  -b isolinux/isolinux.bin
  -c isolinux/boot.cat
  -boot-load-size 4
  -boot-info-table
  -no-emul-boot
  -eltorito-alt-boot
  -e boot/grub/efi.img
  -no-emul-boot
  -isohybrid-gpt-basdat
  -o "$ISO_FILENAME"
  "$IMAGE_DIR"
)
if [ -n "$ISOHYBRID_MBR" ]; then
  XORRISO_ARGS=(-isohybrid-mbr "$ISOHYBRID_MBR" "${XORRISO_ARGS[@]}")
fi

xorriso -as mkisofs "${XORRISO_ARGS[@]}" 2>&1 | tee -a "$LOGFILE"

# ============================================================
# STAGE 11 — Checksum
# ============================================================
log "Generating checksums..."

cd "$OUTPUT_DIR"
sha256sum "$(basename "$ISO_FILENAME")" > "${ISO_FILENAME}.sha256"

log "Build complete!"
log "  ISO:     $ISO_FILENAME"
log "  Size:    $(du -h "$ISO_FILENAME" | cut -f1)"
log "  SHA256:  $(cat "${ISO_FILENAME}.sha256" | cut -d' ' -f1)"
