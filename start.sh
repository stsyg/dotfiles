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

# Preconfigure: Add Debian Sid repo and GPG key (for kubectx)
echo "Setting up Debian Sid repo for kubectx..."
REPO_LINE="deb http://deb.debian.org/debian sid main"
REPO_FILE="/etc/apt/sources.list.d/debian-sid.list"
if ! grep -q "$REPO_LINE" "$REPO_FILE" 2>/dev/null; then
  echo "$REPO_LINE" | sudo tee "$REPO_FILE"
fi

DEBIAN_KEYS_URL="https://ftp-master.debian.org/keys/archive-key-12.asc"
TEMP_KEY_FILE="/tmp/debian-archive-key.asc"
if [ ! -f /etc/apt/trusted.gpg.d/debian-archive-keyring.gpg ]; then
  curl -fsSL "$DEBIAN_KEYS_URL" -o "$TEMP_KEY_FILE"
  gpg --dearmor < "$TEMP_KEY_FILE" | sudo tee /etc/apt/trusted.gpg.d/debian-archive-keyring.gpg > /dev/null
  rm "$TEMP_KEY_FILE"
fi

sudo tee /etc/apt/preferences.d/kubectx.pref > /dev/null <<EOF
Package: *
Pin: release a=jammy
Pin-Priority: 900

Package: *
Pin: release a=sid
Pin-Priority: 100

Package: kubectx
Pin: release a=sid
Pin-Priority: 990
EOF

# Update and upgrade the system after adding all repos
echo "Updating and upgrading the system..."
sudo apt update -y && sudo apt upgrade -y

# Install curl, git, unzip, and fontconfig in one apt command
echo "Installing curl, git, unzip, and fontconfig..."
sudo apt install -y curl git unzip fontconfig bash-completion

# Configure Git
echo "Configuring Git..."
git config --global user.email "$gitemail"
git config --global user.name "$username"

# Install kubectl securely
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl kubectl.sha256

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

  sudo sed -i '/^#PubkeyAuthentication/s/^#//; /^PubkeyAuthentication/s/ no/ yes/' /etc/ssh/sshd_config
  sudo sed -i '/^#PasswordAuthentication/s/^#//; /^PasswordAuthentication/s/ yes/ no/' /etc/ssh/sshd_config
  sudo systemctl restart sshd
else
  echo "No public key provided. Skipping SSH key setup."
fi

# Sudo without password
read -p "Grant $username sudo access without password (y/n)? " sudo_nopass
if [[ $sudo_nopass =~ ^[Yy]$ ]]; then
  if ! sudo grep -q "$username ALL=(ALL) NOPASSWD:ALL" /etc/sudoers.d/$username; then
    echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$username
  fi
  sudo chmod 0440 /etc/sudoers.d/$username
else
  echo "You chose not to set NOPASSWD for $username."
fi

# Set EDITOR and PATH
if ! grep -q 'export EDITOR="/usr/bin/nano"' /home/$username/.bashrc; then
  echo 'export EDITOR="/usr/bin/nano"' >> /home/$username/.bashrc
fi
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' /home/$username/.bashrc; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/$username/.bashrc
fi
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' /home/$username/.bash_profile; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/$username/.bash_profile
fi

# Ensure ~/repos exists
mkdir -p /home/$username/repos
chown $username:$username /home/$username/repos

# Install tfenv
if [ ! -d /home/$username/.tfenv ]; then
  git clone --depth=1 https://github.com/tfutils/tfenv.git /home/$username/.tfenv
  chown -R $username:$username /home/$username/.tfenv
else
  cd /home/$username/.tfenv && git pull
fi
if ! grep -q 'export PATH="$HOME/.tfenv/bin:$PATH"' /home/$username/.bash_profile; then
  echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> /home/$username/.bash_profile
fi
if ! grep -q 'export PATH="$HOME/.tfenv/bin:$PATH"' /home/$username/.bashrc; then
  echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> /home/$username/.bashrc
fi

# kubectl autocomplete
if ! grep -q 'source <(kubectl completion bash)' /home/$username/.bashrc; then
  echo 'source <(kubectl completion bash)' >> /home/$username/.bashrc
fi

# Source bashrc from bash_profile
if ! grep -q 'source ~/.bashrc' /home/$username/.bash_profile; then
  echo -e "\nif [ -f ~/.bashrc ]; then\n   source ~/.bashrc\nfi" >> /home/$username/.bash_profile
fi

# Install Nerd Fonts
latest_release=$(curl --silent "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
mkdir -p /home/$username/.fonts
if [ ! -f /home/$username/.fonts/Meslo.zip ]; then
  wget -q -O /home/$username/.fonts/Meslo.zip https://github.com/ryanoasis/nerd-fonts/releases/download/$latest_release/Meslo.zip
  unzip -o /home/$username/.fonts/Meslo.zip -d /home/$username/.fonts/
  rm /home/$username/.fonts/Meslo.zip
  fc-cache -fv
fi

# Install kubectx
sudo apt install -y -t sid kubectx

# Install Starship
BIN_DIR=/home/$username/.local/bin
mkdir -p $BIN_DIR
curl -sS https://starship.rs/install.sh | sh -s -- -y -b $BIN_DIR
if ! grep -q 'eval "$(starship init bash)"' /home/$username/.bashrc; then
  echo 'eval "$(starship init bash)"' >> /home/$username/.bashrc
fi
if [ ! -f /home/$username/.config/starship.toml ]; then
  mkdir -p /home/$username/.config
  wget -O /home/$username/.config/starship.toml https://raw.githubusercontent.com/stsyg/dotfiles/linux/starship.toml
  chown $username:$username /home/$username/.config/starship.toml
fi

# Create ~/.hello.md
HELLO_FILE="/home/$username/.hello.md"
if [ ! -f "$HELLO_FILE" ]; then
  cat << 'EOF' | tee "$HELLO_FILE" > /dev/null
--------------------------------------------
 hello to your new terminal environment! 
--------------------------------------------

Here are some commands to get started:

- Type "alias" to see all the aliases available.
- Type "tfenv install latest" to install the latest version of Terraform.
- Type "tfenv use latest" to use the latest version of Terraform.
- Type "git --version" to check your Git installation.
- Type "az version" to check your Azure CLI installation.
- Type "starship" to see your terminal prompt in action.
- Type "k version --client" to verify the installation of kubectl.
- Type "kctx" to switch between Kubernetes contexts.
- Type "kns" to switch between Kubernetes namespaces.
- Type "kctxns" to switch to the current namespace in your Kubernetes context.
- Type "k9s" to launch the K9s terminal UI for Kubernetes.
- Type "hello" to see this message again.

Make sure to reload your terminal or run "source ~/.bashrc" to apply all changes.
--------------------------------------------
EOF
  chown $username:$username "$HELLO_FILE"
fi

# Setup aliases
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
  'alias k="kubectl"'
  'alias k9="k9s"'
  'alias hello="cat ~/.hello.md"'
  'alias kctx="kubectx"'
  'alias kns="kubens"'
  'alias kctxns="kubectx $(kubectl config view --minify -o jsonpath="{..namespace}")"'
)
for alias in "${aliases[@]}"; do
  if ! grep -Fxq "$alias" /home/$username/.bash_aliases; then
    echo "$alias" >> /home/$username/.bash_aliases
  fi
done
if ! grep -q 'source ~/.bash_aliases' /home/$username/.bashrc; then
  echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> /home/$username/.bashrc
fi

# Show welcome message
sudo -u $username bash -i -c 'source ~/.bashrc && hello'
