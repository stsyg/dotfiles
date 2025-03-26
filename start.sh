#!/bin/bash

# Ask for input parameters
read -p "Please enter the username: " username
read -p "Please enter your public key (optional): " pubkey
read -p "Please enter your GitHub email: " gitemail

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

# Update and upgrade system (before Debian repo)
echo "Updating and upgrading the system..."
sudo apt update -y && sudo apt upgrade -y

# Install base packages
echo "Installing curl, git, unzip, and fontconfig..."
sudo apt install -y curl git unzip fontconfig bash-completion

# Configure Git
echo "Configuring Git..."
git config --global user.email "$gitemail"
git config --global user.name "$username"

# Install kubectl
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

# SSH key setup
if [ -n "$pubkey" ]; then
  echo "Setting up SSH key for $username..."
  mkdir -p /home/$username/.ssh
  echo "$pubkey" >> /home/$username/.ssh/authorized_keys
  chmod 700 /home/$username/.ssh
  chmod 600 /home/$username/.ssh/authorized_keys
  chown -R $username:$username /home/$username/.ssh

  sudo sed -i '/^#PubkeyAuthentication/s/^#//; /^PubkeyAuthentication/s/ no/ yes/' /etc/ssh/sshd_config
  sudo sed -i '/^#PasswordAuthentication/s/^#//; /^PasswordAuthentication/s/ yes/ no/' /etc/ssh/sshd_config
  sudo systemctl restart sshd
else
  echo "No public key provided. Skipping SSH key setup."
fi

# Sudo NOPASSWD
read -p "Grant $username sudo access without password (y/n)? " sudo_nopass
if [[ $sudo_nopass =~ ^[Yy]$ ]]; then
  echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$username
  sudo chmod 0440 /etc/sudoers.d/$username
else
  echo "You chose not to set NOPASSWD for $username."
fi

# Environment vars
echo 'export EDITOR="/usr/bin/nano"' >> /home/$username/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' | tee -a /home/$username/.bashrc /home/$username/.bash_profile

# Create repos dir
mkdir -p /home/$username/repos
chown $username:$username /home/$username/repos

# Clone tfenv
if [ ! -d /home/$username/.tfenv ]; then
  git clone --depth=1 https://github.com/tfutils/tfenv.git /home/$username/.tfenv
  chown -R $username:$username /home/$username/.tfenv
else
  cd /home/$username/.tfenv && git pull
fi

echo 'export PATH="$HOME/.tfenv/bin:$PATH"' | tee -a /home/$username/.bashrc /home/$username/.bash_profile

# kubectl completion
echo 'source <(kubectl completion bash)' >> /home/$username/.bashrc

# Ensure .bash_profile sources .bashrc
echo -e "\nif [ -f ~/.bashrc ]; then\n   source ~/.bashrc\nfi" >> /home/$username/.bash_profile

# Nerd Fonts
latest_release=$(curl --silent "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
mkdir -p /home/$username/.fonts
wget -q -O /home/$username/.fonts/Meslo.zip https://github.com/ryanoasis/nerd-fonts/releases/download/$latest_release/Meslo.zip
unzip -o /home/$username/.fonts/Meslo.zip -d /home/$username/.fonts/
rm /home/$username/.fonts/Meslo.zip
fc-cache -fv

# Install kubectx from Sid
echo "Setting up kubectx from Debian Sid..."
REPO_LINE="deb http://deb.debian.org/debian sid main"
REPO_FILE="/etc/apt/sources.list.d/debian-sid.list"
echo "$REPO_LINE" | sudo tee "$REPO_FILE"

DEBIAN_KEYS_URL="https://ftp-master.debian.org/keys/archive-key-12.asc"
TEMP_KEY_FILE="/tmp/debian-archive-key.asc"
curl -fsSL "$DEBIAN_KEYS_URL" -o "$TEMP_KEY_FILE"
gpg --dearmor < "$TEMP_KEY_FILE" | sudo tee /etc/apt/trusted.gpg.d/debian-archive-keyring.gpg > /dev/null
rm "$TEMP_KEY_FILE"

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

sudo apt update
sudo apt install -y -t sid kubectx

# Install Starship prompt
BIN_DIR=/home/$username/.local/bin
mkdir -p $BIN_DIR
curl -sS https://starship.rs/install.sh | sh -s -- -y -b $BIN_DIR
echo 'eval "$(starship init bash)"' >> /home/$username/.bashrc

# Starship config
mkdir -p /home/$username/.config
wget -O /home/$username/.config/starship.toml https://raw.githubusercontent.com/stsyg/dotfiles/linux/starship.toml
chown -R $username:$username /home/$username/.config

# Starship config
mkdir -p /home/$username/.kube
wget -O /home/$username/.kube/kubeconfig-manager.sh https://raw.githubusercontent.com/stsyg/dotfiles/linux/kubeconfig-manager.sh
chown -R $username:$username /home/$username/.config
chmod +x /home/$username/kubeconfig-manager.sh


# hello.md (always overwrite)
HELLO_FILE="/home/$username/.hello.md"
cat << 'EOF' | sudo tee "$HELLO_FILE" > /dev/null
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
- Type "kcfg" to add/remove/list/export Kubernetes context.
- Type "k9s" to launch the K9s terminal UI for Kubernetes.
- Type "hello" to see this message again.

Make sure to reload your terminal or run "source ~/.bashrc" to apply all changes.
--------------------------------------------
EOF
chown $username:$username "$HELLO_FILE"

# Aliases
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
  'alias kctx="kubectx"'
  'alias kns="kubens"'
  'alias kctxns="kubectx $(kubectl config view --minify -o jsonpath="{..namespace}")"'
  'alias kcfg="$HOME/.kube/kubeconfig-manager.sh"'
  'alias hello="cat ~/.hello.md"'
)

for alias in "${aliases[@]}"; do
  if ! grep -Fxq "$alias" /home/$username/.bash_aliases; then
    echo "$alias" >> /home/$username/.bash_aliases
  fi
done

if ! grep -q 'source ~/.bash_aliases' /home/$username/.bashrc; then
  echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> /home/$username/.bashrc
fi

# Display hello on first load
sudo -u $username bash -i -c 'source ~/.bashrc && hello'
