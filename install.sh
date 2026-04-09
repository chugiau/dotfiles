#!/usr/bin/env bash
set -euo pipefail

# install.sh — Thin wrapper around bootstrap.sh.
#
# For first-time setup or full reinstall:
#   bash install.sh
#
# For selective install:
#   bash install.sh --tags zsh,neovim
#
# For the full CLI experience, use bin/dotfiles after initial setup.

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
exec bash "${DOTFILES_DIR}/bootstrap.sh" "$@"
