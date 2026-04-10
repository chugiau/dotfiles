#!/bin/sh
# bootstrap.sh — zero-dependency bootstrap for the chezmoi + mise dotfiles.
#
# Assumes the starting environment is the most minimal POSIX shell with
# network access — no bash, no coreutils surprises, no package managers
# already set up.
#
# Flow:
#   1. Detect OS / distro.
#   2. Install the absolute minimum via the system package manager:
#      curl, git, ca-certificates.  (Everything else is handled by the
#      chezmoi run_once scripts after the first `apply`.)
#   3. Install chezmoi and mise into ~/.local/bin.
#   4. Clone the dotfiles repo into ~/.dotfiles if it's not there yet.
#   5. Write ~/.config/chezmoi/chezmoi.toml pointing at the repo.
#   6. Run `chezmoi apply`, which triggers:
#        - run_once_before_10-system-packages.sh.tmpl  (full pkg list)
#        - run_onchange_after_10-mise-install.sh.tmpl  (mise install)
#        - run_once_after_20-ohmyzsh.sh.tmpl           (omz + p10k)
#        - run_once_after_30-nvchad.sh.tmpl            (NvChad starter)
#        - run_onchange_after_40-git-hooks.sh.tmpl     (git hook)
#        - run_once_after_50-default-shell.sh.tmpl     (chsh -s zsh)
#
# Usage:
#   curl -fsSL <raw-url>/bootstrap.sh | sh
#   sh bootstrap.sh

set -eu

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/AbandonedScope/dotfiles.git}"
BIN_DIR="$HOME/.local/bin"

# ── logging ────────────────────────────────────────────────────────────────

log_info()  { printf '\033[0;34m[info]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[ok]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
log_error() { printf '\033[0;31m[error]\033[0m %s\n' "$*" >&2; }

die() {
    log_error "$*"
    exit 1
}

has() {
    command -v "$1" >/dev/null 2>&1
}

# Run a command as root — directly if we already are, via sudo otherwise.
maybe_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif has sudo; then
        sudo "$@"
    else
        die "Need root or sudo to run: $*"
    fi
}

# ── OS detection ───────────────────────────────────────────────────────────

OS=""
DISTRO=""

detect_os() {
    uname_s="$(uname -s)"
    case "$uname_s" in
        Darwin)
            OS=darwin
            ;;
        Linux)
            OS=linux
            if [ -r /etc/os-release ]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                DISTRO="${ID:-unknown}"
            else
                DISTRO=unknown
            fi
            ;;
        *)
            die "Unsupported OS: $uname_s"
            ;;
    esac
    log_info "Detected: os=$OS distro=${DISTRO:-n/a}"
}

# ── Stage 1: minimal prereqs (curl + git) ──────────────────────────────────

install_prereqs() {
    log_info "Ensuring curl and git are available..."

    if [ "$OS" = darwin ]; then
        # git ships via the Xcode Command Line Tools on macOS.
        if ! has git; then
            log_info "Installing Xcode CLI tools (approve the dialog)..."
            xcode-select --install 2>/dev/null || true
            while ! has git; do
                sleep 5
            done
        fi
        has curl || die "curl missing on macOS (unexpected)"
        return 0
    fi

    case "$DISTRO" in
        ubuntu|debian|pop|linuxmint)
            maybe_sudo apt-get update -qq
            maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
                curl git ca-certificates
            ;;
        arch|manjaro|endeavouros)
            maybe_sudo pacman -Sy --noconfirm --needed curl git ca-certificates
            ;;
        fedora)
            maybe_sudo dnf install -y curl git ca-certificates
            ;;
        *)
            if has curl && has git; then
                log_warn "Unknown distro '$DISTRO' — relying on existing curl + git."
            else
                die "Unknown distro '$DISTRO'; install curl and git manually, then re-run."
            fi
            ;;
    esac

    has curl || die "curl still missing after prereq install"
    has git  || die "git still missing after prereq install"
    log_ok "curl + git available"
}

# ── Stage 2: chezmoi ───────────────────────────────────────────────────────

install_chezmoi() {
    if has chezmoi; then
        log_ok "chezmoi already installed: $(command -v chezmoi)"
        return 0
    fi
    if [ -x "$BIN_DIR/chezmoi" ]; then
        PATH="$BIN_DIR:$PATH"
        export PATH
        log_ok "chezmoi already at $BIN_DIR/chezmoi"
        return 0
    fi

    log_info "Installing chezmoi -> $BIN_DIR"
    mkdir -p "$BIN_DIR"
    # The install script supports -b <dir> to target a bin dir.
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$BIN_DIR"

    PATH="$BIN_DIR:$PATH"
    export PATH
    has chezmoi || die "chezmoi install failed"
}

# ── Stage 3: mise ──────────────────────────────────────────────────────────

install_mise() {
    if has mise; then
        log_ok "mise already installed: $(command -v mise)"
        return 0
    fi
    if [ -x "$BIN_DIR/mise" ]; then
        PATH="$BIN_DIR:$PATH"
        export PATH
        log_ok "mise already at $BIN_DIR/mise"
        return 0
    fi

    log_info "Installing mise -> $BIN_DIR (via https://mise.run)"
    mkdir -p "$BIN_DIR"
    curl -fsSL https://mise.run | sh

    PATH="$BIN_DIR:$PATH"
    export PATH
    has mise || log_warn "mise install did not land in PATH; chezmoi will retry later."
}

# ── Stage 4: clone the dotfiles repo ───────────────────────────────────────

clone_repo() {
    if [ -d "$DOTFILES_DIR/.git" ]; then
        log_ok "Dotfiles repo already at $DOTFILES_DIR"
        return 0
    fi
    log_info "Cloning $DOTFILES_REPO_URL -> $DOTFILES_DIR"
    git clone "$DOTFILES_REPO_URL" "$DOTFILES_DIR"
}

# ── Stage 5: write chezmoi config ──────────────────────────────────────────

write_chezmoi_config() {
    cfg_dir="$HOME/.config/chezmoi"
    cfg_file="$cfg_dir/chezmoi.toml"
    mkdir -p "$cfg_dir"

    # Overwrite every bootstrap — the only field we set is sourceDir, and
    # it's always the same.  No interactive data here; the repo is personal.
    cat > "$cfg_file" <<EOF
# Generated by $DOTFILES_DIR/bootstrap.sh — do not edit by hand.
sourceDir = "$DOTFILES_DIR"
EOF
    log_ok "Wrote chezmoi config: $cfg_file"
}

# ── Stage 6: run chezmoi apply ─────────────────────────────────────────────

run_chezmoi_apply() {
    log_info "Running chezmoi apply..."
    chezmoi apply
    log_ok "chezmoi apply finished"
}

# ── main ───────────────────────────────────────────────────────────────────

main() {
    log_info "Dotfiles bootstrap starting..."
    detect_os
    install_prereqs
    install_chezmoi
    install_mise
    clone_repo
    write_chezmoi_config
    run_chezmoi_apply
    log_ok "Bootstrap complete!"
    log_info "Open a new shell to pick up zsh, mise shims and tool paths."
}

main "$@"
