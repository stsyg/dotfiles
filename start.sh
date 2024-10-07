#!/bin/bash

# Ask for input parameters, i.e. username, pubkey, GitHub email
read -p "Please enter the username: " username
read -p "Please enter your public key (optional): " pubkey
read -p "Please enter your GitHub email: " gitemail

# Validate that username is provided
if [ -z "$username" ]; then
  echo "Error: Username is required."
  exit 1
fi

# Add user to sudo and docker groups
if ! groups $username | grep -q "\bsudo\b"; then
  sudo usermod -aG sudo $username
fi
if ! groups $username | grep -q "\bdocker\b"; then
  sudo usermod -aG docker $username
fi

# Update and upgrade the system
echo "Updating and upgrading the system..."
sudo apt update -y && sudo apt upgrade -y

# Install curl, git, unzip, and fontconfig in one apt command to reduce repetition
echo "Installing curl, git, unzip, and fontconfig..."
sudo apt install -y curl git unzip fontconfig bash-completion

# Configure Git with provided email and username
echo "Configuring Git..."
git config --global user.email "$gitemail"
git config --global user.name "$username"

# Install kubectl securely
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl kubectl.sha256  # Clean up downloaded files

# Install K9s
echo "Installing K9s..."
curl -sS https://webinstall.dev/k9s | bash
source ~/.config/envman/PATH.env

# Install Azure CLI
echo "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Handle public key upload securely
if [ -n "$pubkey" ]; then
  echo "Setting up SSH key for $username..."
  mkdir -p /home/$username/.ssh
  if ! grep -q "$pubkey" /home/$username/.ssh/authorized_keys; then
    echo "$pubkey" >> /home/$username/.ssh/authorized_keys
  fi
  chmod 700 /home/$username/.ssh
  chmod 600 /home/$username/.ssh/authorized_keys
  chown -R $username:$username /home/$username/.ssh

  # Update SSHD configuration securely
  sudo sed -i '/^#PubkeyAuthentication/s/^#//; /^PubkeyAuthentication/s/ no/ yes/' /etc/ssh/sshd_config
  sudo sed -i '/^#PasswordAuthentication/s/^#//; /^PasswordAuthentication/s/ yes/ no/' /etc/ssh/sshd_config
  sudo systemctl restart sshd
else
  echo "No public key provided. Skipping SSH key setup."
fi

# Update sudoers file with NOPASSWD option, asking for confirmation
read -p "Grant $username sudo access without password (y/n)? " sudo_nopass
if [[ $sudo_nopass =~ ^[Yy]$ ]]; then
  if ! sudo grep -q "$username ALL=(ALL) NOPASSWD:ALL" /etc/sudoers.d/$username; then
    echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$username
  fi
  sudo chmod 0440 /etc/sudoers.d/$username
else
  echo "You chose not to set NOPASSWD for $username."
fi

# Set EDITOR environment variable if not already present
if ! grep -q 'export EDITOR="/usr/bin/nano"' /home/$username/.bashrc; then
  echo 'export EDITOR="/usr/bin/nano"' >> /home/$username/.bashrc
fi

# Ensure ~/.local/bin exists and is in PATH in both .bashrc and .bash_profile
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' /home/$username/.bashrc; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/$username/.bashrc
fi
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' /home/$username/.bash_profile; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/$username/.bash_profile
fi

# Ensure ~/repos directory exists and set appropriate ownership
mkdir -p /home/$username/repos
chown $username:$username /home/$username/repos

# Clone tfenv repository if not already cloned
if [ ! -d /home/$username/.tfenv ]; then
  git clone --depth=1 https://github.com/tfutils/tfenv.git /home/$username/.tfenv
  chown -R $username:$username /home/$username/.tfenv
else
  cd /home/$username/.tfenv && git pull
fi

# Add tfenv to PATH in ~/.bash_profile and ~/.bashrc
if ! grep -q 'export PATH="$HOME/.tfenv/bin:$PATH"' /home/$username/.bash_profile; then
  echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> /home/$username/.bash_profile
fi
if ! grep -q 'export PATH="$HOME/.tfenv/bin:$PATH"' /home/$username/.bashrc; then
  echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> /home/$username/.bashrc
fi

# Enable kubectl autocompletion, check for duplication
if ! grep -q 'source <(kubectl completion bash)' /home/$username/.bashrc; then
  echo 'source <(kubectl completion bash)' >> /home/$username/.bashrc
fi

# Source .bashrc from .bash_profile
if ! grep -q 'source ~/.bashrc' /home/$username/.bash_profile; then
  echo -e "\nif [ -f ~/.bashrc ]; then\n   source ~/.bashrc\nfi" >> /home/$username/.bash_profile
fi

# Install Meslo Nerd Font
latest_release=$(curl --silent "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
mkdir -p /home/$username/.fonts
if [ ! -f /home/$username/.fonts/Meslo.zip ]; then
  wget -q -O /home/$username/.fonts/Meslo.zip https://github.com/ryanoasis/nerd-fonts/releases/download/$latest_release/Meslo.zip
  unzip -o /home/$username/.fonts/Meslo.zip -d /home/$username/.fonts/
  rm /home/$username/.fonts/Meslo.zip
  fc-cache -fv
fi

# Create BIN_DIR and install Starship prompt
BIN_DIR=/home/$username/.local/bin
mkdir -p $BIN_DIR
curl -sS https://starship.rs/install.sh | sh -s -- -y -b $BIN_DIR

# Initialize Starship in .bashrc, ensuring no duplication
if ! grep -q 'eval "$(starship init bash)"' /home/$username/.bashrc; then
  echo 'eval "$(starship init bash)"' >> /home/$username/.bashrc
fi

# Install Starship config if it doesn't exist
if [ ! -f /home/$username/.config/starship.toml ]; then
  mkdir -p /home/$username/.config
  wget -O /home/$username/.config/starship.toml https://raw.githubusercontent.com/stsyg/dotfiles/linux/starship.toml
  chown $username:$username /home/$username/.config/starship.toml
fi

# Add the welcome function to ~/.bashrc if not already present
if ! grep -q "function welcome" /home/$username/.bashrc; then
  echo 'function welcome() {' >> /home/$username/.bashrc
  echo '  echo "--------------------------------------------"' >> /home/$username/.bashrc
  echo '  echo " Welcome to your new terminal environment! "' >> /home/$username/.bashrc
  echo '  echo "--------------------------------------------"' >> /home/$username/.bashrc
  echo '  echo ""' >> /home/$username/.bashrc
  echo '  echo "Here are some commands to get started:"' >> /home/$username/.bashrc
  echo '  echo ""' >> /home/$username/.bashrc
  echo '  echo "- Type "alias" to see all the aliases available."' >> /home/$username/.bashrc
  echo '  echo "- Type "tfenv install latest" to install the latest version of Terraform."' >> /home/$username/.bashrc
  echo '  echo "- Type "tfenv use latest" to use the latest version of Terraform."' >> /home/$username/.bashrc
  echo '  echo "- Type "k version --client" to verify the installation of kubectl."' >> /home/$username/.bashrc
  echo '  echo "- Type "git --version" to check your Git installation."' >> /home/$username/.bashrc
  echo '  echo "- Type "az version" to check your Azure CLI installation."' >> /home/$username/.bashrc
  echo '  echo "- Type "starship" to see your terminal prompt in action."' >> /home/$username/.bashrc
  echo '  echo "- Type "welcome" to see this message."' >> /home/$username/.bashrc
  echo '  echo ""' >> /home/$username/.bashrc
  echo '  echo "Make sure to reload your terminal or run \"source ~/.bashrc\" to apply all changes."' >> /home/$username/.bashrc
  echo '  echo "--------------------------------------------"' >> /home/$username/.bashrc
  echo '}' >> /home/$username/.bashrc
fi

# Ensure ~/.bash_aliases exists and add custom aliases
touch /home/$username/.bash_aliases
chown $username:$username /home/$username/.bash_aliases

# Define and add aliases to ~/.bash_aliases if not already present
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
  'alias welcome="bash -i -c welcome"'  # Add the welcome alias
)

for alias in "${aliases[@]}"; do
  if ! grep -Fxq "$alias" /home/$username/.bash_aliases; then
    echo "$alias" >> /home/$username/.bash_aliases
  fi
done

# Source ~/.bash_aliases from ~/.bashrc if it's not already sourced
if ! grep -q 'source ~/.bash_aliases' /home/$username/.bashrc; then
  echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> /home/$username/.bashrc
fi

# Source .bashrc to apply the new function in the current shell
sudo -u $username bash -i -c 'source ~/.bashrc && welcome'
