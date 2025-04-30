#!/bin/bash
set -e

# Ask for username and email
read -p "Please enter your username: " username
read -p "Please enter your GitHub email: " gitemail
read -p "Please enter your public SSH key (optional): " pubkey

if [ -z "$username" ]; then
  echo "Error: Username is required."
  exit 1
fi

# Install dev tools
echo ">> Installing development tools..."
yay -S --noconfirm \
  kubectl k9s kubectx helm flux azure-cli docker docker-compose \
  brave-bin google-chrome discord zoom obsidian visual-studio-code-bin \
  lightdm-webkit2-greeter lightdm-webkit-theme-litarvan swaybg cliphist yq \
  lm_sensors acpi alsa-utils playerctl

echo ">> Configuring LightDM WebKit greeter..."
sudo wget -O /etc/lightdm/lightdm.conf https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/lightdm/lightdm.conf
sudo wget -O /etc/lightdm/lightdm-webkit2-greeter.conf https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/lightdm/lightdm-webkit2-greeter.conf
echo ">> LightDM greeter set to 'litarvan' theme. Will apply on next boot."

echo ">> Installing and configuring Waybar..."

# Setup Waybar
echo ">> Installing and configuring Waybar..."
WAYBAR_DIR="/home/$username/.config/waybar"
WAYBAR_SCRIPTS="$WAYBAR_DIR/scripts"
mkdir -p "$WAYBAR_SCRIPTS"
wget -O "$WAYBAR_DIR/style.css" https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/waybar/style.css
wget -O "$WAYBAR_DIR/config.jsonc" https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/waybar/config.jsonc
wget -O "$WAYBAR_SCRIPTS/wifi-status.sh" https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/waybar/wifi-status.sh
chmod +x "$WAYBAR_SCRIPTS/wifi-status.sh"
chown -R "$username:$username" "$WAYBAR_DIR"
echo ">> Waybar configuration complete!"

# # Write Waybar config.jsonc with custom WiFi module
# cat << 'EOF' > "$WAYBAR_DIR/config.jsonc"
# {
#   "modules-right": ["custom/network", "clock"],
#   "custom/network": {
#     "exec": "~/.config/waybar/scripts/wifi-status.sh",
#     "interval": 10,
#     "return-type": "json"
#   }
# }
# EOF

# # Create WiFi status script using iwd
# cat << 'EOF' > "$WAYBAR_SCRIPTS/wifi-status.sh"
# #!/bin/bash

# status=$(iwctl station wlan0 show 2>/dev/null)
# if [[ "$status" == *"connected network"* ]]; then
#     ssid=$(echo "$status" | awk -F': ' '/Connected network/ {print $2}')
#     ip=$(ip addr show wlan0 | awk '/inet / {print $2}' | cut -d/ -f1)
#     echo "{\"text\":\"$ssid\", \"tooltip\":\"IP: $ip\"}"
# else
#     echo '{"text":"Disconnected", "tooltip":"Not connected"}'
# fi
# EOF

# GitHub CLI
echo ">> Installing GitHub CLI..."
sudo pacman -S --noconfirm github-cli

echo ">> Configuring Git..."
git config --global user.name "$username"
git config --global user.email "$gitemail"

# Zsh + tfenv
echo ">> Setting up Zsh and tfenv..."
chsh -s /bin/zsh "$username"
if [ ! -d "/home/$username/.tfenv" ]; then
  sudo -u $username git clone https://github.com/tfutils/tfenv.git /home/$username/.tfenv
fi
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' | tee -a /home/$username/.zshrc /home/$username/.bashrc

echo ">> Installing tfenv..."
if [ ! -d "/home/$username/.tfenv" ]; then
  sudo -u $username git clone https://github.com/tfutils/tfenv.git /home/$username/.tfenv
fi

# Add to groups
echo ">> Setting up user groups (wheel, docker)..."
sudo usermod -aG wheel,docker $username

echo 'export PATH="$HOME/.tfenv/bin:$PATH"' | tee -a /home/$username/.zshrc /home/$username/.bashrc

# Starship Prompt
echo ">> Setting up Starship..."
mkdir -p /home/$username/.config /home/$username/.local/bin
chown -R $username:$username /home/$username/.local
sudo -u $username curl -sS https://starship.rs/install.sh | sh -s -- -y -b /home/$username/.local/bin
echo 'eval "$(starship init zsh)"' >> /home/$username/.zshrc
echo 'eval "$(starship init bash)"' >> /home/$username/.bashrc
wget -O /home/$username/.config/starship.toml https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/starship/starship.toml
chown -R $username:$username /home/$username/.config

# Setup SSH public key if provided
if [ -n "$pubkey" ]; then
  echo ">> Adding SSH key..."
  mkdir -p /home/$username/.ssh
  echo "$pubkey" > /home/$username/.ssh/authorized_keys
  chmod 700 /home/$username/.ssh
  chmod 600 /home/$username/.ssh/authorized_keys
  chown -R $username:$username /home/$username/.ssh
fi

# Setup Docker group access
sudo systemctl enable docker
sudo systemctl start docker

# Download Kubeconfig manager
mkdir -p /home/$username/.kube
wget -O /home/$username/.kube/kubeconfig-manager.sh https://raw.githubusercontent.com/stsyg/dotfiles/linux/kubeconfig/kubeconfig-manager.sh
chmod +x /home/$username/.kube/kubeconfig-manager.sh
chown -R $username:$username /home/$username/.kube

# Create Repos directory
mkdir -p /home/$username/repos
chown -R $username:$username /home/$username/repos

# Hello message
wget -O /home/$username/.hello.md https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/hello/.hello.md
chown $username:$username /home/$username/.hello.md

# # Setup Hello message
# cat << 'EOF' | tee /home/$username/.hello.md > /dev/null
# --------------------------------------------
#  hello to your new terminal environment! 
# --------------------------------------------

# Useful commands:

# - Type "alias" to see all the aliases available.
# - Type "tfenv install latest" to install the latest version of Terraform.
# - Type "tfenv use latest" to use the latest version of Terraform.
# - Type "git --version" to check your Git installation.
# - Type "gh auth login" to login to GitHub CLI.
# - Type "az version" to check your Azure CLI installation.
# - Type "starship" to see your terminal prompt in action.
# - Type "k version --client" to verify the installation of kubectl.
# - Type "kctx" to switch between Kubernetes contexts.
# - Type "kns" to switch between Kubernetes namespaces.
# - Type "kctxns" to switch to the current namespace in your Kubernetes context.
# - Type "kcfg" to add/remove/list/export Kubernetes context.
# - Type "k9s" to launch the K9s terminal UI for Kubernetes.
# --------------------------------------------
# WiFi
# --------------------------------------------
# - Type "iwctl station list" to get list of WiFi adapters
# - Type "iwctl station <station_name> get-networks" to get all available WiFi networks
# - Type "iwctl station <station_name> connect <network_name>" connect to WiFi AP
# - Type "iwctl station <station_name> show" to show WiFi AP connection info
# --------------------------------------------
# --------------------------------------------
# - Type "hello" to see this message again.

# Reload terminal or run "source ~/.zshrc" to apply all changes.
# --------------------------------------------
# EOF

# chown $username:$username /home/$username/.hello.md

# Neovim Config
echo ">> Installing Neovim config..."
sudo -u $username mkdir -p /home/$username/.config/nvim
wget -O /home/$username/.config/nvim/init.lua https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/nvim/init.lua
chown -R $username:$username /home/$username/.config/nvim


# # Install Neovim Config
# echo ">> Installing Neovim (lazy.nvim based) config..."

# sudo -u $username mkdir -p /home/$username/.config/nvim
# cat << 'EOF' > /home/$username/.config/nvim/init.lua
# vim.g.mapleader = " "

# vim.opt.number = true
# vim.opt.relativenumber = true
# vim.opt.tabstop = 4
# vim.opt.shiftwidth = 4
# vim.opt.expandtab = true
# vim.opt.smartindent = true
# vim.opt.termguicolors = true

# local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
# if not vim.loop.fs_stat(lazypath) then
#   vim.fn.system({
#     "git",
#     "clone",
#     "--filter=blob:none",
#     "https://github.com/folke/lazy.nvim.git",
#     lazypath
#   })
# end
# vim.opt.rtp:prepend(lazypath)

# require("lazy").setup({
#     {'nvim-telescope/telescope.nvim', dependencies = {'nvim-lua/plenary.nvim'}},
#     {'nvim-treesitter/nvim-treesitter', build = ':TSUpdate'},
#     {'nvim-lualine/lualine.nvim'},
#     {'folke/which-key.nvim'},
#     {'neovim/nvim-lspconfig'},
#     {'hrsh7th/nvim-cmp', dependencies = {'hrsh7th/cmp-nvim-lsp'}}
# })
# EOF

# chown -R $username:$username /home/$username/.config/nvim

# Tmux Config
wget -O /home/$username/.tmux.conf https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/tmux/.tmux.conf
chown $username:$username /home/$username/.tmux.conf

# # Setup tmux Config
# echo ">> Installing tmux config..."

# cat << 'EOF' > /home/$username/.tmux.conf
# unbind C-b
# set-option -g prefix C-a
# bind-key C-a send-prefix
# bind | split-window -h
# bind - split-window -v
# unbind '"'
# unbind %
# bind h select-pane -L
# bind j select-pane -D
# bind k select-pane -U
# bind l select-pane -R
# bind r source-file ~/.tmux.conf \; display "Reloaded!"
# set-option -g status-bg black
# set-option -g status-fg white
# set -g mouse on
# EOF

# chown $username:$username /home/$username/.tmux.conf

# Hyprland Config
echo ">> Installing Hyprland config..."
mkdir -p /home/$username/.config/hypr
wget -O /home/$username/.config/hypr/hyprland.conf https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/hyprland/hyprland.conf
chown -R $username:$username /home/$username/.config/hypr

# echo ">> Installing Hyprland config..."
# mkdir -p /home/$username/.config/hypr
# wget -O /home/$username/.config/hypr/hyprland.conf https://raw.githubusercontent.com/stsyg/dotfiles/linux/hyprland.conf
# chown -R $username:$username /home/$username/.config/hypr

# Wallpapers
echo ">> Cloning wallpapers..."
WALLPAPER_DIR="/home/$username/pictures/arch-wallpapers"
rm -rf "$WALLPAPER_DIR"
git clone --depth=1 https://github.com/HomeomorphicHooligan/arch-minimal-wallpapers.git "$WALLPAPER_DIR"
chown -R "$username:$username" "$WALLPAPER_DIR"

# echo ">> Copying some wallpapers..."

# WALLPAPER_DIR="/home/$username/Pictures/arch-wallpapers"

# # If the wallpaper folder already exists, remove it
# if [ -d "$WALLPAPER_DIR" ]; then
#   rm -rf "$WALLPAPER_DIR"
# fi

# # Clone the repo fresh
# git clone --depth=1 https://github.com/HomeomorphicHooligan/arch-minimal-wallpapers.git "$WALLPAPER_DIR"

# chown -R "$username:$username" "$WALLPAPER_DIR"


# # Add custom WiFi indicator script for Waybar
# mkdir -p /home/$username/.config/waybar/scripts

# cat << 'EOF' > /home/$username/.config/waybar/scripts/wifi.sh
# #!/bin/bash
# SSID=$(iw dev | grep ssid | awk '{print $2}')
# SIGNAL=$(grep $(iw dev | awk '$1=="Interface"{print $2}') /proc/net/wireless | awk '{ print int($3 * 100 / 70) }')

# if [[ -z "$SSID" ]]; then
#   echo '{"text": "Disconnected", "tooltip": "WiFi not connected", "class": "disconnected"}'
# else
#   echo "{\"text\": \"$SSID ($SIGNAL%)\", \"tooltip\": \"Connected to $SSID\", \"class\": \"connected\"}"
# fi
# EOF

# chmod +x /home/$username/.config/waybar/scripts/wifi.sh
# chown -R $username:$username /home/$username/.config/waybar

# Aliases
echo ">> Setting up aliases..."
ALIASES_FILE="/home/$username/.bash_aliases"
ZSH_ALIASES_FILE="/home/$username/.zsh_aliases"
touch "$ALIASES_FILE"
chown "$username:$username" "$ALIASES_FILE"

aliases=(
  'alias tf="terraform"'
  'alias tfi="terraform init"'
  'alias tfa="terraform apply -auto-approve"'
  'alias tfp="terraform plan"'
  'alias tfd="terraform destroy -auto-approve"'
  'alias ga="git add ."'
  'alias gc="git commit -m"'
  'alias gp="git push"'
  'alias ll="ls -la"'
  'alias cat="bat"'
  'alias k="kubectl"'
  'alias k9="k9s"'
  'alias kctx="kubectx"'
  'alias kns="kubens"'
  'alias kcfg="$HOME/.kube/kubeconfig-manager.sh"'
  'alias hello="cat ~/.hello.md"'
)

# Write aliases if not already present
for alias in "${aliases[@]}"; do
  grep -Fxq "$alias" "$ALIASES_FILE" || echo "$alias" >> "$ALIASES_FILE"
done

cp "$ALIASES_FILE" "$ZSH_ALIASES_FILE"
echo '[[ -f ~/.bash_aliases ]] && source ~/.bash_aliases' >> /home/$username/.bashrc
echo '[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases' >> /home/$username/.zshrc
chown "$username:$username" "$ZSH_ALIASES_FILE" "$ZSHRC"

# echo ">> Setting up aliases..."

# # Create .bash_aliases and ensure permissions
# touch /home/$username/.bash_aliases
# chown $username:$username /home/$username/.bash_aliases

# # Define aliases
# aliases=(
#   'alias tf="terraform"'
#   'alias tfi="terraform init"'
#   'alias tfa="terraform apply -auto-approve"'
#   'alias tfp="terraform plan"'
#   'alias tfd="terraform destroy -auto-approve"'
#   'alias ga="git add ."'
#   'alias gc="git commit -m"'
#   'alias gp="git push"'
#   'alias ll="ls -la"'
#   'alias cat="bat"'  # updated from batcat
#   'alias k="kubectl"'
#   'alias k9="k9s"'
#   'alias kctx="kubectx"'
#   'alias kns="kubens"'
#   'alias kcfg="$HOME/.kube/kubeconfig-manager.sh"'
#   'alias hello="cat ~/.hello.md"'
# )

# # Write aliases if not already present
# for alias in "${aliases[@]}"; do
#   if ! grep -Fxq "$alias" /home/$username/.bash_aliases; then
#     echo "$alias" >> /home/$username/.bash_aliases
#   fi
# done

# # Make sure bash sources aliases
# if ! grep -q 'source ~/.bash_aliases' /home/$username/.bashrc; then
#   echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> /home/$username/.bashrc
# fi

# # Copy to .zsh_aliases for Zsh use
# cp /home/$username/.bash_aliases /home/$username/.zsh_aliases

# # Ensure .zshrc exists and sources aliases
# touch /home/$username/.zshrc
# ZSHRC="/home/$username/.zshrc"
# ZSH_ALIASES_LINE='[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases'
# grep -qxF "$ZSH_ALIASES_LINE" "$ZSHRC" || echo "$ZSH_ALIASES_LINE" >> "$ZSHRC"

# # Fix permissions
# chown $username:$username /home/$username/.zsh_aliases
# chown $username:$username "$ZSHRC"

# Set default shell to Zsh
echo ">> Switching default shell to Zsh for user: $username"
chsh -s /bin/zsh "$username"

echo ">> All post-install configuration is complete!"
