#!/usr/bin/env bash
# ==============================================
# chezmoi bootstrap for private GitHub repo
# ----------------------------------------------
# Uses temporary SSH key at ~/.ssh/bootstrap
# to clone, decrypts permanent SSH key via chezmoi,
# switches remote to permanent key, and cleans up.
# ==============================================

set -euo pipefail

REPO="git@github.com:ilium007/dotfiles.git"
BOOTSTRAP_KEY="$HOME/.ssh/bootstrap"
AGE_KEY_PATH="$HOME/.config/age/keys.txt"

# fastfetch
TAG=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
    | grep -oP '"tag_name":\s*"\K(.*?)(?=")')

curl -L -o /tmp/fastfetch-linux-amd64.deb \
    "https://github.com/fastfetch-cli/fastfetch/releases/download/${TAG}/fastfetch-linux-amd64.deb"
sudo apt install -y /tmp/fastfetch-linux-amd64.deb >/dev/null 2>&1 && \
rm /tmp/fastfetch-linux-amd64.deb >/dev/null 2>&1

# eza
sudo mkdir -p /etc/apt/keyrings && \
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg && \
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list && \
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list && \
sudo apt update && \
sudo apt install -y eza

# fzf
git clone --depth 1 https://github.com/junegunn/fzf.git $HOME/.fzf && $HOME/.fzf/install --all

# Starship
sudo sh -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null 2>&1'

# zap for zsh
zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1

# Install chezmoi if missing
if ! command -v chezmoi >/dev/null 2>&1; then
  echo "Installing chezmoi..."
  sudo sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

# Clone chezmoi repo using bootstrap key
mkdir -p $HOME/.local/share/chezmoi
chmod 700 $HOME/.local/share/chezmoi
echo "Cloning dotfiles repo using bootstrap key..."
export GIT_SSH_COMMAND="ssh -i $BOOTSTRAP_KEY -o IdentitiesOnly=yes"
chezmoi init "$REPO"

# Apply chezmoi configuration
echo "Applying chezmoi configuration..."
chezmoi apply

# Switch chezmoi remote to permanent SSH key
echo "Switching chezmoi repo to permanent SSH key..."
cd $HOME/.local/share/chezmoi
unset GIT_SSH_COMMAND
git remote set-url origin "$REPO"

## uv - install latest python
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install

# Clean up bootstrap key
rm -f "$BOOTSTRAP_KEY"

# Complete
echo "Bootstrap script complete..."
