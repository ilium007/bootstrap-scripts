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

echo "Starting chezmoi bootstrap..."

# Install dependencies
echo "Installing git, curl, and age..."
sudo apt update -y
sudo apt install -y git curl age

# yazi + dependancies
#sudo apt install -y snapd ffmpeg 7zip jq poppler-utils fd-find ripgrep fzf zoxide imagemagick
#sudo snap install snapd

#sudo snap install yazi --classic

#curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest \
#| grep -oP '"tag_name":\s*"\K(.*?)(?=")' \
#| xargs -I{} curl -L -o yazi-amd64.snap \
#  https://github.com/sxyazi/yazi/releases/download/{}/yazi-amd64.snap

#sudo snap install --classic --dangerous yazi-amd64.snap && rm yazi-amd64.snap

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

# Clean up bootstrap key
echo "Cleaning up temporary bootstrap key..."
rm -f "$BOOTSTRAP_KEY"
echo "Chezmoi bootstrap complete at $(date)"
