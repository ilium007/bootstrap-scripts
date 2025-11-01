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

# Step 1. Install dependencies
echo "Installing git, curl, and age..."
sudo apt update -y
sudo apt install -y git curl age

# Install chezmoi if missing
if ! command -v chezmoi >/dev/null 2>&1; then
  echo "Installing chezmoi..."
  sudo sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

# Step 2. Verify bootstrap SSH key
if [ ! -f "$BOOTSTRAP_KEY" ]; then
  echo "Bootstrap SSH key not found: $BOOTSTRAP_KEY"
  echo "Copy temporary key there and try again."
  exit 1
fi
chmod 600 "$BOOTSTRAP_KEY"
mkdir -p ~/.ssh
echo "Bootstrap key found."

# Step 3. Copy age key
if [ ! -f "$AGE_KEY_PATH" ]; then
  echo "Missing Age private key at $AGE_KEY_PATH"
  echo "Copy age key there and try again."
  exit 1
fi
chmod 700 "$(dirname "$AGE_KEY_PATH")"
chmod 600 "$AGE_KEY_PATH"

# Step 4. Clone chezmoi repo using bootstrap key
echo "Cloning dotfiles repo using bootstrap key..."
export GIT_SSH_COMMAND="ssh -i $BOOTSTRAP_KEY -o IdentitiesOnly=yes"
chezmoi init "$REPO"

# Step 5. Apply chezmoi configuration
echo "Applying chezmoi configuration..."
chezmoi apply -v

# Step 6. Switch chezmoi remote to permanent SSH key
echo "Switching chezmoi repo to permanent SSH key..."
cd ~/.local/share/chezmoi
unset GIT_SSH_COMMAND
git remote set-url origin "$REPO"

# Test GitHub access using restored key
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  echo "Permanent SSH key working with GitHub."
else
  echo "Could not verify SSH access to GitHub. Check ~/.ssh/config or permissions."
fi

# Step 7. Clean up bootstrap key
echo "Cleaning up temporary bootstrap key..."
rm -f "$BOOTSTRAP_KEY"
echo "Chezmoi bootstrap complete."
