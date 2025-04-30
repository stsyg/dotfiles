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

# Granting optional sudo NOPASSWD
echo ">> Granting optional sudo NOPASSWD..."
read -p "Grant $username sudo access without password (y/n)? " sudo_nopass
if [[ $sudo_nopass =~ ^[Yy]$ ]]; then
  echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$username
  sudo chmod 0440 /etc/sudoers.d/$username
else
  echo "You chose not to set NOPASSWD for $username."
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
sudo systemctl enable docker
sudo systemctl start docker

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

# Download Kubeconfig manager
echo ">> Downloading kubeconfig manager..."
mkdir -p /home/$username/.kube
wget -O /home/$username/.kube/kubeconfig-manager.sh https://raw.githubusercontent.com/stsyg/dotfiles/linux/kubeconfig/kubeconfig-manager.sh
chmod +x /home/$username/.kube/kubeconfig-manager.sh
chown -R $username:$username /home/$username/.kube

echo ">> Adding kubectl completion..."
echo 'source <(kubectl completion bash)' >> /home/$username/.bashrc
echo 'complete -o default -F __start_kubectl k' >> /home/$username/.bashrc
echo 'source <(kubectl completion zsh)' >> /home/$username/.zshrc
kubectl completion zsh > "/home/$username/.oh-my-zsh/completions/_kubectl" 2>/dev/null || true

# Create Repos directory
echo ">> Creating Repos folder..."
mkdir -p /home/$username/repos
chown -R $username:$username /home/$username/repos

# Hello message
echo ">> Installing hello message..."
wget -O /home/$username/.hello.md https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/hello/.hello.md
chown $username:$username /home/$username/.hello.md

# Neovim Config
echo ">> Installing Neovim config..."
sudo -u $username mkdir -p /home/$username/.config/nvim
wget -O /home/$username/.config/nvim/init.lua https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/nvim/init.lua
chown -R $username:$username /home/$username/.config/nvim

# Tmux Config
echo ">> Installing tmux config..."
wget -O /home/$username/.tmux.conf https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/tmux/.tmux.conf
chown $username:$username /home/$username/.tmux.conf

# Hyprland Config
echo ">> Installing Hyprland config..."
mkdir -p /home/$username/.config/hypr
wget -O /home/$username/.config/hypr/hyprland.conf https://raw.githubusercontent.com/stsyg/dotfiles/linux/arch/hyprland/hyprland.conf
chown -R $username:$username /home/$username/.config/hypr

# Wallpapers
echo ">> Cloning arch wallpapers..."
WALLPAPER_DIR="/home/$username/pictures/arch-wallpapers"
rm -rf "$WALLPAPER_DIR"
git clone --depth=1 https://github.com/HomeomorphicHooligan/arch-minimal-wallpapers.git "$WALLPAPER_DIR"
chown -R "$username:$username" "$WALLPAPER_DIR"

# Aliases
echo ">> Setting up aliases..."
touch /home/$username/.bash_aliases /home/$username/.zsh_aliases
ALIASES_FILE="/home/$username/.bash_aliases"
ZSH_ALIASES_FILE="/home/$username/.zsh_aliases"
ZSHRC="/home/$username/.zshrc"

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

# Set default shell to Zsh
echo ">> Switching default shell to Zsh for user: $username"
chsh -s /bin/zsh "$username"

echo ">> All post-install configuration is complete!"