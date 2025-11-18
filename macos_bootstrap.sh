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
echo "Installing homebrew, git and age..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew update
brew install git age

# Install chezmoi if missing
if ! command -v chezmoi >/dev/null 2>&1; then
  echo "Installing chezmoi..."
  brew install chezmoi
fi

# Step 2. Verify bootstrap SSH key
if [ ! -f "$BOOTSTRAP_KEY" ]; then
  echo "Bootstrap SSH key not found: $BOOTSTRAP_KEY"
  echo "Paste the private key below, then press CTRL-D:"
  mkdir -p "$(dirname "$BOOTSTRAP_KEY")"
  cat > "$BOOTSTRAP_KEY"
  chmod 600 "$BOOTSTRAP_KEY"
  echo "Bootstrap key saved."
fi
echo "Bootstrap key found."

# Step 3. Copy age key
if [ ! -f "$AGE_KEY_PATH" ]; then
  echo "Missing Age private key at $AGE_KEY_PATH"
  echo "Paste the Age key below, then press CTRL-D:"
  mkdir -p "$(dirname "$AGE_KEY_PATH")"
  cat > "$AGE_KEY_PATH"
  chmod 600 "$AGE_KEY_PATH"
  echo "Age key saved."
fi

# Step 4. Pre-create chezmoi config
echo "Creating chezmoi config for age decryption..."
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

# Step 9. Install everything else
echo "Installing shell apps..."

brew install eza fastfetch

# --- FZF + Oh-My-Zsh + plugins ------------------------------------------------
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && yes | ~/.fzf/install --all'
RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# --- Install Starship prompt --------------------------------------------------
sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y -b /usr/local/bin

# git config
git config --global user.email "brantwinter@gmail.com"
git config --global user.name "Brant Winter"

