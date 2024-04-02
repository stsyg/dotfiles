#!/bin/bash

# Ask for input parameters, i.e. username, pubkey, etc.
read -p "Please enter the username: " username
read -p "Please enter your public key (optional): " pubkey

# Check if username is empty
if [ -z "$username" ]; then
  echo "Error: Username is required"
  exit 1
fi

# Add user to sudo group
sudo usermod -aG sudo $username

# Update and upgrade the system
sudo apt update -y && sudo apt upgrade -y

# Install curl and git
sudo apt install -y curl git fontconfig

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Set up SSH key if pubkey is not empty
if [ -n "$pubkey" ]; then
  mkdir -p /home/$username/.ssh
  if ! grep -q "$pubkey" /home/$username/.ssh/authorized_keys; then
    echo $pubkey >> /home/$username/.ssh/authorized_keys
  fi
  chmod 700 /home/$username/.ssh
  chmod 600 /home/$username/.ssh/authorized_keys
  chown -R $username:$username /home/$username/.ssh
 
  # Update SSHD configuration
  sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  sudo sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config
  sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo systemctl restart sshd
fi

# Update sudoers file
if ! sudo grep -q "$username ALL=(ALL) NOPASSWD:ALL" /etc/sudoers.d/$username; then
  echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$username
fi
sudo chmod 0440 /etc/sudoers.d/$username

# Set EDITOR environment variable
if ! grep -q 'export EDITOR="/usr/bin/nano"' /home/$username/.bashrc; then
  echo 'export EDITOR="/usr/bin/nano"' >> /home/$username/.bashrc
fi

# Add ~/.local/bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Ensure ~/repos exists
mkdir -p /home/$username/repos
chown $username:$username /home/$username/repos

# Clone tfenv repository
if [ ! -d /home/$username/.tfenv ]; then
  git clone --depth=1 https://github.com/tfutils/tfenv.git /home/$username/.tfenv
  chown -R $username:$username /home/$username/.tfenv
fi

# Add tfenv to PATH in ~/.bash_profile
if ! grep -q 'export PATH="$HOME/.tfenv/bin:$PATH"' /home/$username/.bash_profile; then
  echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> /home/$username/.bash_profile
fi

# Add tfenv to PATH in ~/.bashrc
if ! grep -q 'export PATH=$PATH:$HOME/.tfenv/bin' /home/$username/.bashrc; then
  echo 'export PATH=$PATH:$HOME/.tfenv/bin' >> /home/$username/.bashrc
fi

# Ensure ~/.bash_aliases exists
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
  'alias k="kubectl"'
)

# Add each alias to ~/.bash_aliases if it does not exist
for alias in "${aliases[@]}"; do
  if ! grep -Fxq "$alias" /home/$username/.bash_aliases; then
    echo "$alias" >> /home/$username/.bash_aliases
  fi
done

# Source ~/.bash_aliases from ~/.bashrc
if ! grep -q 'source ~/.bash_aliases' /home/$username/.bashrc; then
  echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> /home/$username/.bashrc
fi

# Source .bashrc from .bash_profile
if ! grep -q 'source ~/.bashrc' /home/$username/.bash_profile; then
  echo -e "\nif [ -f ~/.bashrc ]; then\n   source ~/.bashrc\nfi" >> /home/$username/.bash_profile
fi

# Get latest release tag from GitHub
latest_release=$(curl --silent "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# Download and install Meslo Nerd Font
mkdir -p /home/$username/.fonts
wget -q -O /home/$username/.fonts/Meslo.zip https://github.com/ryanoasis/nerd-fonts/releases/download/$latest_release/Meslo.zip
unzip -o /home/$username/.fonts/Meslo.zip -d /home/$username/.fonts/
rm /home/$username/.fonts/Meslo.zip
fc-cache -fv

# Create BIN_DIR if it does not exist
BIN_DIR=~/.local/bin
mkdir -p $BIN_DIR

# Install Starship
curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin

# Initialize Starship
if ! grep -q 'eval "$(starship init bash)"' /home/$username/.bashrc; then
  echo 'eval "$(~/.local/bin/starship init bash)"' >> /home/$username/.bashrc
fi

# Check if ~/.config/starship.toml exists and if not, copy one from the local folder
if [ ! -f /home/$username/.config/starship.toml ]; then
  mkdir -p /home/$username/.config
  wget -O /home/$username/.config/starship.toml https://raw.githubusercontent.com/stsyg/dotfiles/linux/starship.toml
  chown $username:$username /home/$username/.config/starship.toml
fi
