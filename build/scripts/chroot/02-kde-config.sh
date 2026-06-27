#!/bin/bash
# Modelink Workstation — KDE Plasma Configuration (runs in chroot)
set -euo pipefail

# Create skeleton directory for new users
SKEL_DIR="/etc/skel"

# Wallpaper
mkdir -p "${SKEL_DIR}/.local/share/wallpapers"
cp /usr/share/wallpapers/modelink/* "${SKEL_DIR}/.local/share/wallpapers/" 2>/dev/null || true

# KDE config directory
mkdir -p "${SKEL_DIR}/.config"

# Apply KDE configuration defaults
cat > "${SKEL_DIR}/.config/kdeglobals" << 'EOF'
[General]
ColorScheme=ModelinkDark
Name=ModelinkDark
widgetStyle=Breeze
font=Inter,10,-1,5,50,0,0,0,0,0
fixed=JetBrains Mono,10,-1,5,50,0,0,0,0,0

[KDE]
AnimationDurationFactor=0.25

[Icons]
Theme=breeze-dark
EOF

# Default applications
cat > "${SKEL_DIR}/.config/mimeapps.list" << 'EOF'
[Default Applications]
text/plain=kate.desktop
text/code=kate.desktop
inode/directory=dolphin.desktop
terminal/terminal=org.kde.konsole.desktop
EOF

# Configure Konsole profile
mkdir -p "${SKEL_DIR}/.local/share/konsole"
cat > "${SKEL_DIR}/.local/share/konsole/Modelink.profile" << 'EOF'
[Appearance]
ColorScheme=Breeze
Font=JetBrains Mono,10

[General]
Name=Modelink
Parent=FALLBACK/

[Scrolling]
HistoryMode=2
EOF

# Set default Konsole profile
cat > "${SKEL_DIR}/.config/konsolerc" << 'EOF'
[Desktop Entry]
DefaultProfile=Modelink.profile
EOF

# Configure Dolphin
cat > "${SKEL_DIR}/.config/dolphinrc" << 'EOF'
[General]
ShowFullPath=true
ShowZoomSlider=true

[KFileDialog Settings]
Recent URLs=file:///home/engineer/Workspace
ShowHiddenFiles=false
EOF

# Configure Kate
cat > "${SKEL_DIR}/.config/katerc" << 'EOF'
[General]
Show Full Path=true

[UiSettings]
ColorScheme=Breeze Dark
Font=JetBrains Mono,10
TabBar Style=1
EOF

# Configure SDDM
cat > /etc/sddm.conf << 'EOF'
[Autologin]
Relogin=false
Session=plasma.desktop
User=

[Theme]
Current=modelink
CursorTheme=breeze_cursors
Font=Inter,10

[Users]
MaximumUid=65000
MinimumUid=1000

[Wayland]
Session=plasmawayland
EOF

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/kde_settings.conf << 'EOF'
[Theme]
Current=breeze
EOF
