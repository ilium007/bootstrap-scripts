#!/usr/bin/env bash
set -euo pipefail

USER="$1"
USER_HOME="/home/${USER}"
REPO="git@github.com:ilium007/dotfiles.git"
BOOTSTRAP_KEY="${USER_HOME}/.ssh/bootstrap"
AGE_KEY_PATH="${USER_HOME}/.config/age/keys.txt"

run_as_user() {
    su - "$USER" -c "$1"
}

##############################################
# fastfetch
##############################################
TAG=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
    | grep -oP '"tag_name":\s*"\K(.*?)(?=")')

curl -L -o /tmp/fastfetch.deb \
    "https://github.com/fastfetch-cli/fastfetch/releases/download/${TAG}/fastfetch-linux-amd64.deb"

apt install -y /tmp/fastfetch.deb
rm -f /tmp/fastfetch.deb

##############################################
# eza
##############################################
mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg

echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    > /etc/apt/sources.list.d/gierens.list

chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
apt update
apt install -y eza

##############################################
# fzf (user-local)
##############################################
run_as_user "git clone --depth 1 https://github.com/junegunn/fzf.git ${USER_HOME}/.fzf"
run_as_user "${USER_HOME}/.fzf/install --all"

##############################################
# Starship (user-local)
##############################################
sh -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y'

##############################################
# zap for zsh (user-local)
##############################################
run_as_user "zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1"

##############################################
# Install chezmoi (system)
##############################################
if ! command -v chezmoi >/dev/null 2>&1; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

##############################################
# Init chezmoi using bootstrap key
##############################################
run_as_user "mkdir -p ${USER_HOME}/.local/share/chezmoi"
run_as_user "chmod 700 ${USER_HOME}/.local/share/chezmoi"

run_as_user "GIT_SSH_COMMAND='ssh -i ${BOOTSTRAP_KEY} -o IdentitiesOnly=yes' chezmoi init '${REPO}'"

##############################################
# Apply chezmoi config
##############################################
run_as_user "chezmoi apply"

##############################################
# Switch remote to permanent SSH key
##############################################
run_as_user "cd ${USER_HOME}/.local/share/chezmoi && git remote set-url origin '${REPO}'"

##############################################
# uv + python (user local)
##############################################
run_as_user "curl -LsSf https://astral.sh/uv/install.sh | sh"
run_as_user "uv python install"

##############################################
# Cleanup
##############################################
rm -f "${BOOTSTRAP_KEY}"

echo "Bootstrap script complete."
