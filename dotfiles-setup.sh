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
  yq

echo ">> Setting up user groups (wheel, docker)..."
sudo usermod -aG wheel,docker $username

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

echo ">> Setting up Starship prompt..."
mkdir -p /home/$username/.config
sudo -u $username curl -sS https://starship.rs/install.sh | sh -s -- -y -b /home/$username/.local/bin
echo 'eval "$(starship init zsh)"' >> /home/$username/.zshrc
echo 'eval "$(starship init bash)"' >> /home/$username/.bashrc

# Download custom starship config
wget -O /home/$username/.config/starship.toml https://raw.githubusercontent.com/stsyg/dotfiles/linux/starship.toml
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

echo ">> Setting up aliases..."
touch /home/$username/.bash_aliases
chown $username:$username /home/$username/.bash_aliases

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
  'alias cat="batcat"'
  'alias k="kubectl"'
  'alias k9="k9s"'
  'alias kctx="kubectx"'
  'alias kns="kubens"'
  'alias kcfg="$HOME/.kube/kubeconfig-manager.sh"'
  'alias hello="cat ~/.hello.md"'
)

for alias in "${aliases[@]}"; do
  if ! grep -Fxq "$alias" /home/$username/.bash_aliases; then
    echo "$alias" >> /home/$username/.bash_aliases
  fi
done

# Source bash aliases automatically
if ! grep -q 'source ~/.bash_aliases' /home/$username/.bashrc; then
  echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> /home/$username/.bashrc
fi

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

- tfenv install latest && tfenv use latest
- k9s to manage Kubernetes clusters
- az login to log into Azure
- starship to enjoy your prompt
- code . to launch VSCode
- hello to show this message

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

echo ">> All post-install configuration is complete!"
