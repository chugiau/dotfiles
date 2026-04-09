#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh — Minimal bootstrap for dotfiles provisioning.
#
# Ensures git and ansible are available, clones the dotfiles repo if needed,
# copies the default config, and runs the Ansible playbook.
#
# Usage:
#   curl -fsSL <raw-url>/bootstrap.sh | bash          # first-time setup
#   bash bootstrap.sh                                  # from within the repo
#   bash bootstrap.sh --tags zsh                       # install specific role
#   bash bootstrap.sh --check --diff                   # dry-run

readonly DOTFILES_DIR="${HOME}/.dotfiles"
readonly REPO_URL="${DOTFILES_REPO:-https://github.com/AbandonedScope/dotfiles.git}"

# --- Helpers ---

log_info()  { printf '\033[0;34m[info]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[ok]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
log_error() { printf '\033[0;31m[error]\033[0m %s\n' "$*" >&2; }

command_exists() { command -v "$1" &>/dev/null; }

# --- Install Ansible if missing ---

install_ansible() {
  if command_exists ansible-playbook; then
    log_ok "ansible-playbook already available"
    return 0
  fi

  log_info "Installing Ansible..."

  case "$(uname -s)" in
    Darwin)
      if ! command_exists brew; then
        log_info "Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      brew install ansible
      ;;
    Linux)
      if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        case "${ID:-}" in
          ubuntu|debian)
            sudo apt-get update -qq
            sudo apt-get install -y -qq software-properties-common
            sudo apt-add-repository -y --update ppa:ansible/ansible
            sudo apt-get install -y -qq ansible
            ;;
          arch|manjaro|endeavouros)
            sudo pacman -Sy --noconfirm ansible
            ;;
          fedora)
            sudo dnf install -y ansible
            ;;
          *)
            log_info "Unknown distro '${ID}', trying pipx..."
            if command_exists pipx; then
              pipx install ansible-core
            elif command_exists pip3; then
              pip3 install --user ansible-core
            else
              log_error "Cannot install Ansible — install it manually and re-run."
              exit 1
            fi
            ;;
        esac
      else
        log_error "Cannot detect Linux distribution. Install Ansible manually."
        exit 1
      fi
      ;;
    *)
      log_error "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac

  if command_exists ansible-playbook; then
    log_ok "Ansible installed successfully"
  else
    log_error "Ansible installation failed"
    exit 1
  fi
}

# --- Install community.general collection if missing ---

install_collections() {
  if ansible-galaxy collection list community.general &>/dev/null; then
    return 0
  fi
  log_info "Installing Ansible community.general collection..."
  ansible-galaxy collection install community.general
}

# --- Clone dotfiles repo if not present ---

clone_dotfiles() {
  if [ -d "${DOTFILES_DIR}" ]; then
    log_ok "Dotfiles repo already at ${DOTFILES_DIR}"
    return 0
  fi

  if ! command_exists git; then
    log_error "git is not installed. Install it and re-run."
    exit 1
  fi

  log_info "Cloning dotfiles to ${DOTFILES_DIR}..."
  git clone "${REPO_URL}" "${DOTFILES_DIR}"
}

# --- Ensure group_vars/all.yml exists ---

setup_config() {
  local config="${DOTFILES_DIR}/group_vars/all.yml"
  local example="${DOTFILES_DIR}/group_vars/all.yml.example"

  if [ -f "${config}" ]; then
    return 0
  fi

  if [ -f "${example}" ]; then
    cp "${example}" "${config}"
    log_info "Created group_vars/all.yml from template."
    log_info "Edit it to customize your setup: ${config}"
  else
    log_warn "No all.yml.example found — using defaults from roles."
  fi
}

# --- Main ---

main() {
  log_info "Dotfiles bootstrap starting..."

  install_ansible
  install_collections
  clone_dotfiles
  setup_config

  log_info "Running Ansible playbook..."
  cd "${DOTFILES_DIR}"
  ansible-playbook site.yml "$@"

  log_ok "Bootstrap complete!"
}

main "$@"
