#!/bin/bash

set -e

echo ">> Updating system..."
sudo pacman -Syu --noconfirm

echo ">> Installing essential packages..."
sudo pacman -S --noconfirm \
  base-devel \                 # Build essentials (make, gcc, etc.) — needed for AUR and compiling
  git \                        # Version control (GitHub, GitLab)
  curl \                       # Download tool for APIs, scripts, etc.
  wget \                       # Older alternative to curl — good for raw file downloads
  unzip \                      # Extract .zip archives
  zip \                        # Create .zip archives
  vim \                        # Terminal text editor (fallback if nvim unavailable)
  zsh \                        # Modern shell (will replace bash after setup)
  starship \                   # Fast and customizable shell prompt
  bat \                        # Pretty `cat` replacement with syntax highlighting
  fd \                         # Modern replacement for `find` (simpler syntax, faster)
  ripgrep \                    # Modern `grep` (search through code fast)
  fzf \                        # Fuzzy finder — used in `kubectx`, terminals, and scripts
  htop \                       # Interactive process viewer (`top`, but better)
  lsd \                        # Modern `ls` command with icons, colors
  reflector \                  # Tool to fetch fastest Arch mirrors
  bash-completion \            # Tab-completion for bash (useful pre-zsh switch)
  tmux \                       # Terminal multiplexer (splits, detached sessions)
  neovim \                     # Modern Vim rewrite (IDE-ready terminal editor)
  alacritty \                  # GPU-accelerated Wayland-compatible terminal
  rofi \                       # App launcher and dmenu replacement
  waybar \                     # Status bar for Hyprland (clock, battery, etc.)
  hyprland \                   # Wayland tiling window manager (your desktop)
  lightdm \                    # Login screen/display manager
  lightdm-gtk-greeter \        # GTK-based greeter theme for LightDM
  iwd \                        # Systemd-friendly WiFi daemon (replaces wpa_supplicant). Connect using iwctl
  pipewire \                   # Modern audio engine (PulseAudio + JACK replacement)
  pipewire-pulse \             # PipeWire compatibility with PulseAudio apps
  pipewire-alsa \              # PipeWire compatibility with ALSA
  pipewire-jack \              # PipeWire compatibility with JACK apps
  wireplumber \                # PipeWire session manager (controls streams/devices)
  dunst \                      # Lightweight notification daemon (Wayland-safe)
  grim \                       # Wayland screenshot utility (takes screenshots)
  slurp \                      # Selects screen region (used with grim)
  swappy \                     # Annotates screenshots (cropping, arrows, etc.)
  wl-clipboard \               # Wayland clipboard CLI (copy/paste from terminal)
  brightnessctl \              # CLI brightness control (for laptops)
  playerctl \                  # Control media players (play/pause/next from status bar)
  xdg-desktop-portal-hyprland \  # Portal backend for Hyprland (app integration)
  thunar \                     # Lightweight GUI file manager (Xfce's)
  thunar-archive-plugin \      # Archive support in Thunar (right-click extract)
  file-roller \                # Archive manager (GUI alternative to unzip/7z)
  p7zip \                      # .7z archive compression/extraction support
  unrar \                      # .rar file support
  noto-fonts \                 # Modern Unicode font (broad language support)
  ttf-liberation \             # Microsoft font replacements (Arial, Times, etc.)
  ttf-jetbrains-mono \         # Developer-friendly monospace font
  ttf-nerd-fonts-symbols       # Nerd fonts (icons in status bars, terminals)

echo ">> Enabling essential services..."
sudo systemctl enable lightdm            # Enable login screen
sudo systemctl enable iwd                # Enable networking (WiFi)
systemctl --user enable pipewire         # Enable user-level audio service
systemctl --user enable pipewire-pulse   # PulseAudio compatibility
systemctl --user enable wireplumber      # Audio session manager

echo ">> Installing Yay (AUR helper)..."
if ! command -v yay &> /dev/null
then
  cd /tmp
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm                # Build and install yay from AUR
fi

echo ">> System base setup complete!"
