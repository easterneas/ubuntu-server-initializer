#!/bin/bash

# This script should be run as a non-root user with sudo privileges.
# It performs an unattended initial setup for Ubuntu Server, with an interactive prompt for SSH public key.

# Check if running as root and exit if so
if [ "$EUID" -eq 0 ]; then
    echo "Error: This script must be run as a non-root user with sudo privileges. Do not run as root."
    exit 1
fi

# Exit on error
set -e

# Function to validate public key format
validate_pubkey() {
    local key="$1"
    if [[ $key =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com)\  ]]; then
        return 0
    else
        return 1
    fi
}

# Prompt for public key at the beginning
while true; do
    read -p "Please provide your SSH public key (e.g., 'ssh-ed25519 <key> user@host'): " PUBKEY
    if [ -n "$PUBKEY" ] && validate_pubkey "$PUBKEY"; then
        break
    else
        echo "Invalid public key format. It should start with 'ssh-rsa', 'ssh-ed25519', etc., followed by the key and optional comment."
    fi
done

# Update and upgrade the system (minor updates only)
sudo apt update -y
sudo apt upgrade -y
sudo apt autoremove -y

# Harden security
# Install and configure UFW firewall
sudo apt install ufw -y
sudo ufw allow OpenSSH
sudo ufw --force enable

# Configure SSH for key-only authentication and disable root login
sudo sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Add the provided public key to authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "$PUBKEY" >> ~/.ssh/authorized_keys

# Install Fail2Ban for additional protection against brute-force attacks
sudo apt install fail2ban -y

# Install kitty, fish, and set fish as default shell
sudo apt install kitty fish -y
chsh -s $(which fish)

# Install nvm (Node Version Manager) for the current user
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Source nvm to make it available in the current session (optional, for immediate use)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install fisher (fish package manager)
fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'

# Install nvm.fish plugin for nvm in fish
fish -c 'fisher install jorgebucaran/nvm.fish'

chsh -s $(which fish)

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

echo "Setup complete. You may need to log out and log back in for shell changes to take effect."
echo "For Tailscale, run 'tailscale up' to authenticate and connect."
echo "SSH is now configured for key-only authentication. Test a new login with your key before closing this session."
