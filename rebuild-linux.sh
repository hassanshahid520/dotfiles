#!/usr/bin/env bash
# Re-apply home.nix on Linux after a change (the Linux twin of rebuild.sh).
set -euo pipefail
case "$(uname -m)" in aarch64) HOST="linux-aarch64" ;; *) HOST="linux" ;; esac
exec home-manager switch --flake "$HOME/.dotfiles#$HOST" --impure -b backup
