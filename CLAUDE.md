@AGENTS.md

# Dotfiles

Personal environment provisioning system using Ansible.

## Quick Start

```bash
# First-time setup (installs Ansible if needed, runs full playbook)
bash bootstrap.sh

# After setup, use the CLI wrapper
dotfiles install              # Full install
dotfiles install zsh neovim   # Specific roles
dotfiles update               # Update omz, p10k, brew, nvim plugins
dotfiles doctor               # Health check
dotfiles check                # Dry-run
```

## Architecture

- **`site.yml`** — Main Ansible playbook
- **`roles/`** — One role per concern: `homebrew`, `core`, `zsh`, `cli_tools`, `neovim`, `dotfiles`
- **`group_vars/all.yml`** — User config (gitignored); copy from `all.yml.example`
- **`pre_tasks/`** — WSL detection, Homebrew detection, XDG setup
- **`bin/dotfiles`** — CLI wrapper
- **`bootstrap.sh`** — First-time bootstrap (installs Ansible, runs playbook)

## Roles

| Role | What it does | PM strategy |
|------|-------------|-------------|
| `homebrew` | Install/ensure Homebrew | N/A |
| `core` | git, git-lfs, jq, openssh, gpg | System PM always |
| `zsh` | zsh, oh-my-zsh, powerlevel10k | System PM for zsh |
| `cli_tools` | bat, eza, lazygit | Homebrew (default) or system PM |
| `neovim` | neovim 0.11+, NvChad starter | Homebrew (default) or system PM |
| `dotfiles` | Symlinks, hooks, secrets, alias fixups | N/A |

## Adding a new distro

Drop a `<OsFamily>.yml` in the role's `tasks/` directory (e.g., `Archlinux.yml`, `RedHat.yml`).
The `main.yml` auto-discovers it via `ansible.builtin.stat` + `include_tasks`.

## Config convention

- `*.symlink` files are linked to `~/.<basename>` (e.g., `zsh/zshrc.symlink` → `~/.zshrc`)
- `secrets/*.env.example` files are copied to `*.env` on first run (never committed)
- `git/hooks/*` are linked into `.git/hooks/`

## Testing

```bash
bash tests/test_bootstrap.sh   # Smoke tests (syntax, lint)
molecule test                   # Docker integration tests
ansible-playbook site.yml --check --diff   # Dry-run
```
