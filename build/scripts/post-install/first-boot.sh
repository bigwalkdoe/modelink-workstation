#!/bin/bash
# ============================================================
# Modelink Workstation — First Boot Initialization Script
# Runs once on first login via systemd service
# ============================================================
set -euo pipefail

LOG_FILE="/var/log/modelink-first-boot.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Modelink Workstation First Boot Initialization ==="
echo "Started: $(date)"

# ---- Configuration ----
WORKSPACE_BASE="$HOME/Workspace"
USER_NAME="${SUDO_USER:-engineer}"
USER_HOME="/home/${USER_NAME}"

# ---- 1. System Update ----
echo "[1/8] Updating system packages..."
apt-get update
apt-get upgrade -y
apt-get autoremove -y

# ---- 2. Git Configuration ----
echo "[2/8] Configuring Git (defaults)..."
cat > "$USER_HOME/.gitconfig" << 'EOF'
[init]
    defaultBranch = main
[core]
    editor = code --wait
    autocrlf = input
[push]
    autoSetupRemote = true
[fetch]
    prune = true
[color]
    ui = auto
EOF
chown "${USER_NAME}:${USER_NAME}" "$USER_HOME/.gitconfig"

# ---- 3. SSH Key Generation (if not exists) ----
echo "[3/8] Setting up SSH..."
mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"

if [ ! -f "$USER_HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "modelink-${USER_NAME}" -f "$USER_HOME/.ssh/id_ed25519" -N ""
  echo "SSH key generated: $USER_HOME/.ssh/id_ed25519.pub"
  cat "$USER_HOME/.ssh/id_ed25519.pub"
fi

chown -R "${USER_NAME}:${USER_NAME}" "$USER_HOME/.ssh"

# ---- 4. Workspace Creation ----
echo "[4/8] Creating workspace structure..."
mkdir -p \
  "${WORKSPACE_BASE}/Projects" \
  "${WORKSPACE_BASE}/Clients" \
  "${WORKSPACE_BASE}/Research" \
  "${WORKSPACE_BASE}/Agents" \
  "${WORKSPACE_BASE}/AI/Models" \
  "${WORKSPACE_BASE}/AI/Datasets" \
  "${WORKSPACE_BASE}/AI/Agents" \
  "${WORKSPACE_BASE}/AI/Inference" \
  "${WORKSPACE_BASE}/Containers" \
  "${WORKSPACE_BASE}/Infrastructure/Terraform" \
  "${WORKSPACE_BASE}/Infrastructure/Ansible" \
  "${WORKSPACE_BASE}/Infrastructure/Kubernetes" \
  "${WORKSPACE_BASE}/Automation/Scripts" \
  "${WORKSPACE_BASE}/Automation/CI-CD" \
  "${WORKSPACE_BASE}/Scripts" \
  "${WORKSPACE_BASE}/Templates/Project" \
  "${WORKSPACE_BASE}/Templates/Agent" \
  "${WORKSPACE_BASE}/Templates/Infrastructure" \
  "${WORKSPACE_BASE}/Archives" \
  "${WORKSPACE_BASE}/Backups"

chown -R "${USER_NAME}:${USER_NAME}" "$WORKSPACE_BASE"

# ---- 5. Shell Enhancement ----
echo "[5/8] Configuring shell..."
cat >> "$USER_HOME/.bashrc" << 'BASHRC'

# ---- Modelink Workstation Shell Configuration ----

# Aliases
alias ll='eza -la --icons'
alias la='eza -a --icons'
alias l='eza --icons'
alias lt='eza -T --icons'
alias cat='bat'
alias grep='rg'
alias top='btop'
alias df='duf'
alias du='ncdu --color dark'
alias find='fd'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias vi='nvim'
alias vim='nvim'
alias dc='docker compose'
alias k='kubectl'
alias tf='terraform'
alias ta='tmux attach'
alias ts='tmux new-session'

# History
HISTSIZE=100000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Prompt
if command -v starship &>/dev/null; then
  eval "$(starship init bash)"
else
  PS1='\[\e[38;5;99m\]\u\[\e[0m\]@\[\e[38;5;99m\]\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
fi

# Development helpers
export EDITOR="code --wait"
export VISUAL="code --wait"
export PAGER="less"
export BROWSER="xdg-open"

# Path
export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"
export PATH="$HOME/Workspace/Scripts:$PATH"

# Source additional completions
[ -f /usr/share/bash-completion/bash_completion ] && source /usr/share/bash-completion/bash_completion

# FZF
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash

# Zoxide
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

# Atuin
command -v atuin &>/dev/null && eval "$(atuin init bash)"
BASHRC

chown "${USER_NAME}:${USER_NAME}" "$USER_HOME/.bashrc"

# ---- 6. Install Starship Prompt ----
echo "[6/8] Installing Starship prompt..."
if ! command -v starship &>/dev/null; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y 2>/dev/null || true
fi

cat > "$USER_HOME/.config/starship.toml" << 'STARSHIP'
format = """\
[](#7C4DFF)\
$os\
$username\
[](bg:#7C4DFF fg:#141414)\
$directory\
[](fg:#7C4DFF bg:#242424)\
$git_branch\
$git_status\
[](fg:#242424 bg:#1A1A1A)\
$container\
$fill\
$cmd_duration\
$line_break\
$character\
"""

[os]
disabled = false
style = "bg:#7C4DFF fg:#141414"

[os.format]
windows = "[$symbol]($style)"
unix = "[$symbol]($style)"

[username]
show_always = true
style_user = "bg:#7C4DFF fg:#141414"
style_root = "bg:#7C4DFF fg:#141414"
format = "[ $user ]($style)"

[directory]
style = "bg:#7C4DFF fg:#E0E0E0"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[directory.substitutions]
"Documents" = "📄 "
"Downloads" = "⬇ "
"github" = "🐙 "

[git_branch]
format = "[ $symbol$branch ]($style)"
style = "bg:#242424 fg:#7C4DFF"

[git_status]
style = "bg:#242424 fg:#9E9E9E"
format = "[$all_status$ahead_behind]($style)"

[nodejs]
format = "[ $symbol($version) ]($style)"
style = "bg:#242424 fg:#7C4DFF"

[python]
format = "[ $symbol($version) ]($style)"
style = "bg:#242424 fg:#7C4DFF"

[rust]
format = "[ $symbol($version) ]($style)"
style = "bg:#242424 fg:#7C4DFF"

[golang]
format = "[ $symbol($version) ]($style)"
style = "bg:#242424 fg:#7C4DFF"

[container]
style = "bg:#242424 fg:#E0E0E0"
format = "[ $symbol $name ]($style)"

[cmd_duration]
format = "[⏱ $duration]($style)"
style = "bg:#1A1A1A fg:#9E9E9E"

[character]
success_symbol = "[❯](bold #7C4DFF)"
error_symbol = "[❯](bold #F44336)"
vimcmd_symbol = "[❮](bold #4CAF50)"
STARSHIP

chown -R "${USER_NAME}:${USER_NAME}" "$USER_HOME/.config"

# ---- 7. Modelink CLI ----
echo "[7/8] Installing Modelink CLI..."
cat > /usr/local/bin/modelink << 'MODELINK_CLI'
#!/bin/bash
# Modelink Workstation CLI — Development Environment Manager

MODELINK_VERSION="1.0.0"

show_help() {
  cat << HELP
Modelink Workstation CLI v${MODELINK_VERSION}

Usage:
  modelink init          Initialize project templates
  modelink agent         Launch AI agent workspace
  modelink workspace     Show workspace structure
  modelink containers    Show running containers
  modelink services      Show system services
  modelink info          Show system information
  modelink update        Update Modelink packages
  modelink doctor        Check system health
  modelink version       Show version
HELP
}

case "${1:-help}" in
  init)
    echo "Project templates initialized in ~/Workspace/Templates/"
    ls -la ~/Workspace/Templates/
    ;;
  agent)
    echo "AI Agent environment ready"
    echo "Use ~/Workspace/Agents/ for agent projects"
    ;;
  workspace)
    echo "Workspace Structure:"
    find ~/Workspace -maxdepth 2 -type d | sort
    ;;
  containers)
    podman ps -a 2>/dev/null || docker ps -a 2>/dev/null || echo "No container runtime found"
    ;;
  services)
    systemctl list-units --type=service --state=running | head -20
    ;;
  info)
    echo "Modelink Workstation v${MODELINK_VERSION}"
    echo "Ubuntu $(lsb_release -rs)"
    echo "KDE Plasma $(plasmashell --version 2>/dev/null | cut -d' ' -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    ;;
  update)
    sudo apt-get update && sudo apt-get upgrade -y
    ;;
  doctor)
    echo "Checking system health..."
    echo "  CPU: $(nproc) cores"
    echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  Disk: $(df -h / | awk 'NR==2 {print $4}') available"
    echo "  GPU: $(lspci | grep -i 'vga\|3d\|display' | head -1 | cut -d: -f3-)" 2>/dev/null
    ;;
  version)
    echo "Modelink Workstation v${MODELINK_VERSION}"
    ;;
  *)
    show_help
    ;;
esac
MODELINK_CLI
chmod +x /usr/local/bin/modelink

# ---- 8. Welcome Message ----
echo "[8/8] Setting up welcome message..."
cat > /etc/update-motd.d/99-modelink << 'MOTD'
#!/bin/bash
echo ""
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║     Modelink Workstation v1.0             ║"
echo "  ║     AI-Native Engineering Platform        ║"
echo "  ╚═══════════════════════════════════════════╝"
echo ""
echo "  📁 Workspace: ~/Workspace"
echo "  💻 Type 'modelink help' for available commands"
echo "  🚀 From Power On to Productive in Under 10 Minutes"
echo ""
MOTD
chmod +x /etc/update-motd.d/99-modelink

echo ""
echo "=== Modelink Workstation Initialization Complete ==="
echo "Restart your terminal or run: source ~/.bashrc"
echo "Log: $LOG_FILE"
echo "Completed: $(date)"
