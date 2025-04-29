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

echo ">> Installing development tools..."
yay -S --noconfirm \
  kubectl \
  k9s \
  kubectx \
  helm \
  flux \
  azure-cli \
  docker \
  docker-compose \
  brave-bin \
  google-chrome \
  discord \
  zoom \
  obsidian \
  visual-studio-code-bin \
  lightdm-webkit2-greeter \
  lightdm-webkit-theme-litarvan \
  yq

echo ">> Installing prettier LightDM greeter..."

# Install LightDM webkit2 greeter and a nice theme (Litarvan)
yay -S --noconfirm lightdm-webkit2-greeter lightdm-webkit-theme-litarvan

# Configure LightDM to use the webkit2 greeter
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
if grep -q "^#greeter-session=" "$LIGHTDM_CONF"; then
  sudo sed -i 's|^#greeter-session=.*|greeter-session=lightdm-webkit2-greeter|' "$LIGHTDM_CONF"
elif grep -q "^greeter-session=" "$LIGHTDM_CONF"; then
  sudo sed -i 's|^greeter-session=.*|greeter-session=lightdm-webkit2-greeter|' "$LIGHTDM_CONF"
else
  echo -e "\n[Seat:*]\ngreeter-session=lightdm-webkit2-greeter" | sudo tee -a "$LIGHTDM_CONF"
fi

# Set theme to litarvan
LIGHTDM_WEBKIT_CONF="/etc/lightdm/lightdm-webkit2-greeter.conf"
if [ -f "$LIGHTDM_WEBKIT_CONF" ]; then
  sudo sed -i 's|^webkit-theme *=.*|webkit-theme = litarvan|' "$LIGHTDM_WEBKIT_CONF" || echo -e "[greeter]\nwebkit-theme = litarvan" | sudo tee "$LIGHTDM_WEBKIT_CONF"
else
  echo -e "[greeter]\nwebkit-theme = litarvan" | sudo tee "$LIGHTDM_WEBKIT_CONF"
fi

echo ">> LightDM WebKit greeter set to 'litarvan'. Will apply on next boot."

echo ">> Installing GitHub CLI..."
sudo pacman -S --noconfirm github-cli

echo ">> Configuring Git..."
git config --global user.name "$username"
git config --global user.email "$gitemail"

echo ">> Setting Zsh as default shell..."
chsh -s /bin/zsh $username

echo ">> Installing tfenv..."
if [ ! -d "/home/$username/.tfenv" ]; then
  sudo -u $username git clone https://github.com/tfutils/tfenv.git /home/$username/.tfenv
fi

echo 'export PATH="$HOME/.tfenv/bin:$PATH"' | tee -a /home/$username/.zshrc /home/$username/.bashrc

echo ">> Setting up user groups (wheel, docker)..."
sudo usermod -aG wheel,docker $username

echo ">> Setting up Starship prompt..."

# Ensure config and bin directories exist
mkdir -p /home/$username/.config
mkdir -p /home/$username/.local/bin
chown -R $username:$username /home/$username/.local

# Install Starship using the official script as the target user
sudo -u $username curl -sS https://starship.rs/install.sh | sh -s -- -y -b /home/$username/.local/bin

# Initialize Starship in both Zsh and Bash
echo 'eval "$(starship init zsh)"' >> /home/$username/.zshrc
echo 'eval "$(starship init bash)"' >> /home/$username/.bashrc

# Download custom Starship config
sudo -u $username wget -O /home/$username/.config/starship.toml https://raw.githubusercontent.com/stsyg/dotfiles/linux/starship.toml
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

# Download kubeconfig manager
mkdir -p /home/$username/.kube
wget -O /home/$username/.kube/kubeconfig-manager.sh https://raw.githubusercontent.com/stsyg/dotfiles/linux/kubeconfig-manager.sh
chmod +x /home/$username/.kube/kubeconfig-manager.sh
chown -R $username:$username /home/$username/.kube

# Create Repos directory
mkdir -p /home/$username/repos
chown -R $username:$username /home/$username/repos

# Setup Hello message
cat << 'EOF' | tee /home/$username/.hello.md > /dev/null
--------------------------------------------
 hello to your new terminal environment! 
--------------------------------------------

Useful commands:

- Type "alias" to see all the aliases available.
- Type "tfenv install latest" to install the latest version of Terraform.
- Type "tfenv use latest" to use the latest version of Terraform.
- Type "git --version" to check your Git installation.
- Type "gh auth login" to login to GitHub CLI.
- Type "az version" to check your Azure CLI installation.
- Type "starship" to see your terminal prompt in action.
- Type "k version --client" to verify the installation of kubectl.
- Type "kctx" to switch between Kubernetes contexts.
- Type "kns" to switch between Kubernetes namespaces.
- Type "kctxns" to switch to the current namespace in your Kubernetes context.
- Type "kcfg" to add/remove/list/export Kubernetes context.
- Type "k9s" to launch the K9s terminal UI for Kubernetes.
- Type "hello" to see this message again.

Reload terminal or run "source ~/.zshrc" to apply all changes.
--------------------------------------------
EOF

chown $username:$username /home/$username/.hello.md

# Install Neovim Config
echo ">> Installing Neovim (lazy.nvim based) config..."

sudo -u $username mkdir -p /home/$username/.config/nvim
cat << 'EOF' > /home/$username/.config/nvim/init.lua
vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.termguicolors = true

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {'nvim-telescope/telescope.nvim', dependencies = {'nvim-lua/plenary.nvim'}},
    {'nvim-treesitter/nvim-treesitter', build = ':TSUpdate'},
    {'nvim-lualine/lualine.nvim'},
    {'folke/which-key.nvim'},
    {'neovim/nvim-lspconfig'},
    {'hrsh7th/nvim-cmp', dependencies = {'hrsh7th/cmp-nvim-lsp'}}
})
EOF

chown -R $username:$username /home/$username/.config/nvim

# Setup tmux Config
echo ">> Installing tmux config..."

cat << 'EOF' > /home/$username/.tmux.conf
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
bind r source-file ~/.tmux.conf \; display "Reloaded!"
set-option -g status-bg black
set-option -g status-fg white
set -g mouse on
EOF

chown $username:$username /home/$username/.tmux.conf

echo ">> Installing Hyprland config..."
mkdir -p /home/$username/.config/hypr
wget -O /home/$username/.config/hypr/hyprland.conf https://raw.githubusercontent.com/stsyg/dotfiles/linux/hyprland.conf
chown -R $username:$username /home/$username/.config/hypr


echo ">> Setting up aliases..."

# Create .bash_aliases and ensure permissions
touch /home/$username/.bash_aliases
chown $username:$username /home/$username/.bash_aliases

# Define aliases
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
  'alias cat="bat"'  # updated from batcat
  'alias k="kubectl"'
  'alias k9="k9s"'
  'alias kctx="kubectx"'
  'alias kns="kubens"'
  'alias kcfg="$HOME/.kube/kubeconfig-manager.sh"'
  'alias hello="cat ~/.hello.md"'
)

# Write aliases if not already present
for alias in "${aliases[@]}"; do
  if ! grep -Fxq "$alias" /home/$username/.bash_aliases; then
    echo "$alias" >> /home/$username/.bash_aliases
  fi
done

# Make sure bash sources aliases
if ! grep -q 'source ~/.bash_aliases' /home/$username/.bashrc; then
  echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> /home/$username/.bashrc
fi

# Copy to .zsh_aliases for Zsh use
cp /home/$username/.bash_aliases /home/$username/.zsh_aliases

# Ensure .zshrc exists and sources aliases
touch /home/$username/.zshrc
ZSHRC="/home/$username/.zshrc"
ZSH_ALIASES_LINE='[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases'
grep -qxF "$ZSH_ALIASES_LINE" "$ZSHRC" || echo "$ZSH_ALIASES_LINE" >> "$ZSHRC"

# Fix permissions
chown $username:$username /home/$username/.zsh_aliases
chown $username:$username "$ZSHRC"

# Set default shell to Zsh
echo ">> Switching default shell to Zsh for user: $username"
chsh -s /bin/zsh "$username"

echo ">> All post-install configuration is complete!"
