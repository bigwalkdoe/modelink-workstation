#!/bin/bash
# Modelink Workstation — System Configuration (runs in chroot)
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ---- System Configuration ----
echo "modelink" > /etc/hostname
echo "127.0.1.1 modelink.local modelink" >> /etc/hosts

# ---- Locale ----
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ---- Default Shell ----
chsh -s /bin/bash root

# ---- Services (some may not be installed yet — skip gracefully) ----
systemctl enable sddm              2>/dev/null || true
systemctl enable NetworkManager    2>/dev/null || true
systemctl enable ufw               2>/dev/null || true
systemctl enable fail2ban          2>/dev/null || true
systemctl enable ssh               2>/dev/null || true
systemctl enable systemd-resolved  2>/dev/null || true
systemctl enable avahi-daemon      2>/dev/null || true
systemctl enable bluetooth         2>/dev/null || true

# ---- Firewall ----
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

# ---- SSH Hardening ----
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true

# ---- AppArmor ----
systemctl enable apparmor

# ---- Systemd Journal -#
sed -i 's/#Storage=auto/Storage=persistent/' /etc/systemd/journald.conf

# ---- Clean up ----
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
