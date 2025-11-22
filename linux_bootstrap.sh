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

# Update
sudo apt update && \
sudo apt full-upgrade

# Install binaries
sudo apt update -y
sudo apt install -y \
git \
curl \
age \
zip \
vim \
dnsutils \
gpg \
ca-certificates \
rsync \
lsof \
sudo \
tmux \
zsh \
gdisk \
tree \
inotify-tools

# fastfetch
TAG=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
    | grep -oP '"tag_name":\s*"\K(.*?)(?=")')

curl -L -o fastfetch-linux-amd64.deb \
    "https://github.com/fastfetch-cli/fastfetch/releases/download/${TAG}/fastfetch-linux-amd64.deb"
sudo apt install -y ./fastfetch-linux-amd64.deb >/dev/null 2>&1 && \
rm ./fastfetch-linux-amd64.deb >/dev/null 2>&1

# eza
sudo mkdir -p /etc/apt/keyrings && \
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg && \
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list && \
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list && \
sudo apt update && \
sudo apt install -y eza

# fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all

# Starship
#curl -sS https://starship.rs/install.sh | sh -s -- -y
sudo sh -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null 2>&1'

# zap for zsh
zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1

# Install chezmoi if missing
if ! command -v chezmoi >/dev/null 2>&1; then
  echo "Installing chezmoi..."
  sudo sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

## Verify bootstrap SSH key
if [ ! -f "$BOOTSTRAP_KEY" ]; then
  echo "Bootstrap SSH key not found: $BOOTSTRAP_KEY"
  echo "Paste the private key below, then press CTRL-D:"
  mkdir -p "$(dirname "$BOOTSTRAP_KEY")"
  cat > "$BOOTSTRAP_KEY"
  chmod 600 "$BOOTSTRAP_KEY"
  echo "Bootstrap key saved."
fi
echo "Bootstrap key found."

## Copy age key
if [ ! -f "$AGE_KEY_PATH" ]; then
  echo "Missing age private key at $AGE_KEY_PATH"
  echo "Paste the age key below, then press CTRL-D:"
  mkdir -p "$(dirname "$AGE_KEY_PATH")"
  cat > "$AGE_KEY_PATH"
  chmod 600 "$AGE_KEY_PATH"
  echo "Age key saved."
fi

# Pre-create chezmoi config
echo "Creating chezmoi config for age decryption..."
mkdir -p ~/.config/chezmoi
chmod 700 ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<'EOF'
encryption = "age"

[age]
  identity = "~/.config/age/keys.txt"
  recipient = "age1uxeeu6l4zwyhjhevwkpf85sa7n964tdqgnadh5897t0slwg2uvmqjkqsvs"

[git]
    autoCommit = true
    autoPush = true
EOF

chmod 600 ~/.config/chezmoi/chezmoi.toml

# Clone chezmoi repo using bootstrap key
mkdir -p ~/.local/share/chezmoi
chmod 700 ~/.local/share/chezmoi
echo "Cloning dotfiles repo using bootstrap key..."
export GIT_SSH_COMMAND="ssh -i $BOOTSTRAP_KEY -o IdentitiesOnly=yes"
chezmoi init "$REPO"

# Apply chezmoi configuration
echo "Applying chezmoi configuration..."
chezmoi apply

# Switch chezmoi remote to permanent SSH key
echo "Switching chezmoi repo to permanent SSH key..."
cd ~/.local/share/chezmoi
unset GIT_SSH_COMMAND
git remote set-url origin "$REPO"

## uv - install latest python
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install

# Clean up bootstrap key
echo "Cleaning up temporary bootstrap key..."
rm -f "$BOOTSTRAP_KEY"
