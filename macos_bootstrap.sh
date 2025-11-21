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

echo "Starting macOS bootstrap..."

# Install dependencies
echo "Installing homebrew, git and age..."
if [ ! -f /opt/homebrew/bin/brew ]; then
  echo "Homebrew not installed. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

for pkg in git age; do
  if ! brew list --formula | grep -q "^$pkg$"; then
    brew update
    brew install "$pkg"
  fi
done

# xcode command line tools
if xcode-select -p &> /dev/null; then
  echo "Xcode command line tools are already installed."
else
  echo "Installing Xcode command line tools..."
  xcode-select --install &> /dev/null
  echo "Xcode command line tools installed successfully."
fi

# Install chezmoi if missing
if ! command -v chezmoi >/dev/null 2>&1; then
  echo "Installing chezmoi..."
  brew install chezmoi
fi

# Verify bootstrap SSH key
if [ ! -f "$BOOTSTRAP_KEY" ]; then
  echo "Bootstrap SSH key not found: $BOOTSTRAP_KEY"
  echo "Paste the private key below, then press CTRL-D:"
  mkdir -p "$(dirname "$BOOTSTRAP_KEY")"
  cat > "$BOOTSTRAP_KEY"
  chmod 600 "$BOOTSTRAP_KEY"
  echo "Bootstrap key saved."
fi
echo "Bootstrap key found."

# Copy age key
if [ ! -f "$AGE_KEY_PATH" ]; then
  echo "Missing age private key at $AGE_KEY_PATH"
  echo "Paste the age key below, then press CTRL-D:"
  mkdir -p "$(dirname "$AGE_KEY_PATH")"
  cat > "$AGE_KEY_PATH"
  chmod 600 "$AGE_KEY_PATH"
  echo "Age key saved."
fi

# Create chezmoi config
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

# Clone chezmoi repo using bootstrap key
mkdir -p ~/.local/share/chezmoi
chmod 700 ~/.local/share/chezmoi
echo "Cloning dotfiles repo using bootstrap key..."
export GIT_SSH_COMMAND="ssh -i $BOOTSTRAP_KEY -o IdentitiesOnly=yes"
chezmoi init "$REPO"

# Switch chezmoi remote to permanent SSH key
echo "Switching chezmoi repo to permanent SSH key..."
cd ~/.local/share/chezmoi
unset GIT_SSH_COMMAND
git remote set-url origin "$REPO"

# Clean up bootstrap key
echo "Cleaning up temporary bootstrap key..."
rm -f "$BOOTSTRAP_KEY"

# git config
git config --global user.email "brantwinter@gmail.com"
git config --global user.name "Brant Winter"

# mas installs
# DOESN'T WORK
#mas install \
#1451544217 \ # Adobe Lightroom
#1153157709 \
#1451685025 \

#uv
uv python install

# Install Zap ZSH plugin manager
if [[ ! -d "${XDG_DATA_HOME:-$HOME/.local/share}/zap" ]]; then
  echo "Installing Zap ZSH plugin manager..."
  zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1
  echo "Removing .zshrc so chezmoi can manage it..."
  rm -f ~/.zshrc
fi

# Apply chezmoi
echo "Applying chezmoi..."
chezmoi apply -v

# Install applications via Brewfile
# REPLACE WITH BREWFILE
if [[ -f ./Brewfile ]]; then
  echo "Installing applications from Brewfile..."
  brew bundle --file=./Brewfile
else
  echo "Warning: Brewfile not found in current directory"
  # some default brew apps
  brew install eza fzf fastfetch yazi uv zsh-completions
fi

# Re-source Homebrew env just in case
eval "$(/opt/homebrew/bin/brew shellenv)"

# Bootstrap complete
echo "Bootstrap complete..."

# Optionally restart the shell
exec zsh -l

