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
#chmod 600 "$BOOTSTRAP_KEY"
#mkdir -p ~/.ssh
echo "Bootstrap key found."

# Step 3. Copy age key
#mkdir -p "$(dirname "$AGE_KEY_PATH")"
#chmod 700 "$(dirname "$AGE_KEY_PATH")"
if [ ! -f "$AGE_KEY_PATH" ]; then
  echo "Missing Age private key at $AGE_KEY_PATH"
  echo "Copy age key there and try again."
  exit 1
fi
#chmod 600 "$AGE_KEY_PATH"

# Step 4. Pre-create chezmoi config
echo "Creating chezmoi config for age decryption..."
#mkdir -p ~/.config/chezmoi
#chmod 700 ~/.config/chezmoi
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

# Step 5. Clone chezmoi repo using bootstrap key
mkdir -p ~/.local/share/chezmoi
chmod 700 ~/.local/share/chezmoi
echo "Cloning dotfiles repo using bootstrap key..."
export GIT_SSH_COMMAND="ssh -i $BOOTSTRAP_KEY -o IdentitiesOnly=yes"
chezmoi init "$REPO"

# Step 6. Apply chezmoi configuration
echo "Applying chezmoi configuration..."
chezmoi apply -v

# Step 7. Switch chezmoi remote to permanent SSH key
echo "Switching chezmoi repo to permanent SSH key..."
cd ~/.local/share/chezmoi
unset GIT_SSH_COMMAND
git remote set-url origin "$REPO"

# Step 8. Clean up bootstrap key
echo "Cleaning up temporary bootstrap key..."
rm -f "$BOOTSTRAP_KEY"
echo "Chezmoi bootstrap complete at $(date)"