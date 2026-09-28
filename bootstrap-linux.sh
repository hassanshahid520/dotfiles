#!/usr/bin/env bash
# Takes an Ubuntu/Debian machine from nothing to this dotfiles setup:
# Nix + standalone home-manager (same home.nix as the Mac), zsh as login shell,
# WezTerm, herdr and Claude Code. Re-running is safe; use ./rebuild-linux.sh
# for day-to-day changes.
#
#   ./bootstrap-linux.sh            # desktop machine (installs WezTerm)
#   ./bootstrap-linux.sh --no-gui   # server / Jetson over SSH (skips WezTerm)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GUI=1
[ "${1:-}" = "--no-gui" ] && GUI=0

case "$(uname -m)" in
  x86_64)  HOST="linux" ;;
  aarch64) HOST="linux-aarch64" ;;
  *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

step() { printf '\n==> %s\n' "$*"; }

step "apt packages (curl, git, zsh)"
sudo apt-get update -qq
sudo apt-get install -y -qq curl git zsh ca-certificates gpg

if [ "$GUI" = 1 ]; then
  step "WezTerm (official apt repo)"
  if ! command -v wezterm >/dev/null; then
    curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' \
      | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
    sudo apt-get update -qq && sudo apt-get install -y -qq wezterm
  else
    echo "    already installed"
  fi
fi

step "Determinate Nix"
if ! command -v nix >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
fi
# make nix usable in this shell even right after installing
# shellcheck disable=SC1091
[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

step "Link this repo to ~/.dotfiles"
# home.nix points its config symlinks through ~/.dotfiles
if [ "$DIR" != "$(readlink -f ~/.dotfiles 2>/dev/null || true)" ]; then
  ln -sfn "$DIR" ~/.dotfiles
fi

step "home-manager switch (#$HOST)"
# --impure: the flake reads $USER. -b backup: existing files such as ~/.zshrc
# are renamed to *.backup instead of making the switch fail.
nix run github:nix-community/home-manager/release-26.05 -- \
  switch --flake "$HOME/.dotfiles#$HOST" --impure -b backup

step "zsh as login shell"
ZSH_PATH="$(command -v zsh)"   # apt's /usr/bin/zsh (listed in /etc/shells); reads home-manager's ~/.zshrc
if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
  sudo chsh -s "$ZSH_PATH" "$USER"
  echo "    changed - takes effect on next login"
else
  echo "    already zsh"
fi

step "Claude Code"
if ! command -v claude >/dev/null && [ ! -x "$HOME/.local/bin/claude" ]; then
  curl -fsSL https://claude.ai/install.sh | bash
else
  echo "    already installed"
fi

step "herdr"
if ! command -v herdr >/dev/null && [ ! -x "$HOME/.local/bin/herdr" ]; then
  curl -fsSL https://herdr.dev/install.sh | sh
else
  echo "    already installed"
fi

step "Done"
cat <<EOF
Next:
  - Log out and back in (zsh becomes your shell, fonts get picked up).
  - Open WezTerm (or SSH in), run 'nvim' once so lazy.nvim installs plugins.
  - Set git identity: git config --global user.name / user.email
  - After editing home.nix or flake.nix: ./rebuild-linux.sh
    (files under home/ are symlinked, so edits there are live)
EOF
