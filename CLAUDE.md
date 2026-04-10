@AGENTS.md

# Dotfiles

Personal environment provisioning using [chezmoi](https://www.chezmoi.io/) for dotfiles and [mise](https://mise.jdx.dev/) for CLI tool versions.

## Quick Start

```sh
# First-time setup (zero-dependency POSIX sh bootstrap)
sh bootstrap.sh

# After setup, use the CLI wrapper
dotfiles install      # chezmoi apply + mise install
dotfiles update       # chezmoi update + mise upgrade + omz + p10k + nvim plugins
dotfiles link         # Re-apply chezmoi (re-create managed files)
dotfiles check        # Dry-run (chezmoi diff)
dotfiles doctor       # Health check
```

## Architecture

- **`bootstrap.sh`** — POSIX sh, zero-dependency bootstrap. Installs curl/git/ca-certs via system PM, drops chezmoi and mise into `~/.local/bin`, clones the repo, writes `~/.config/chezmoi/chezmoi.toml`, runs `chezmoi apply`.
- **`.chezmoiroot`** — contains `home`. Points chezmoi at `home/` as its source directory.
- **`home/`** — chezmoi source root, mirrors `$HOME`. File naming follows chezmoi conventions (`dot_`, `executable_`, `private_`, `run_once_*`, `run_onchange_*`).
- **`home/dot_config/mise/config.toml`** — mise tool manifest (neovim, bat, eza, lazygit, glow).
- **`home/dot_config/dotfiles/`** — runtime tree deployed by chezmoi:
  - `modules/*.zsh` — shell modules sourced by zshrc (alias, functions, fzf, pkg-quarantine, secrets, ssh-agent)
  - `hooks/pre-commit` — source for the repo's own git pre-commit hook
  - `secrets/credentials.env.example` — template for local secrets
- **`home/run_once_*.sh.tmpl`** — chezmoi setup scripts (system packages, mise install, oh-my-zsh + p10k, NvChad, git hooks, chsh).
- **`bin/dotfiles`** — POSIX sh CLI wrapper around chezmoi + mise.
- **`tests/test_smoke.sh`** — POSIX sh structural tests + chezmoi template render checks.

## Environment variables

| Variable | Points at | Purpose |
|---|---|---|
| `$DOTFILES_REPO` | `$HOME/.dotfiles` | Git checkout |
| `$DOTFILES` | `$HOME/.config/dotfiles` | chezmoi runtime tree — modules, secrets |

zshrc sources `$DOTFILES/modules/*.zsh`, so editing the source in `home/dot_config/dotfiles/modules/` and re-running `dotfiles link` redeploys it.

## chezmoi run_once flow

Ordering uses numeric prefixes:

| Script | Phase | Trigger |
|---|---|---|
| `run_once_before_10-system-packages.sh.tmpl` | before apply | once |
| `run_onchange_after_10-mise-install.sh.tmpl` | after apply | whenever mise config hash changes |
| `run_once_after_20-ohmyzsh.sh.tmpl` | after apply | once |
| `run_once_after_30-nvchad.sh.tmpl` | after apply | once |
| `run_onchange_after_40-git-hooks.sh.tmpl` | after apply | whenever hook content hash changes |
| `run_once_after_50-default-shell.sh.tmpl` | after apply | once |

Go templates dispatch on `.chezmoi.os` (`darwin` / `linux`) and `.chezmoi.osRelease.id` (`ubuntu` / `debian` / `arch` / `fedora` / …).

## Adding a distro

Edit `home/run_once_before_10-system-packages.sh.tmpl` — add a new `install_<distro>()` function and an `else if` branch in the Go-template dispatch block. No other file to touch.

## Adding a tool

1. Edit `home/dot_config/mise/config.toml`, add the tool line.
2. `dotfiles install` — the content hash in `run_onchange_after_10-mise-install.sh.tmpl` changes, chezmoi re-runs it, mise picks up the new tool.
3. Optional: add the binary name to the `doctor` loop in `bin/dotfiles`.

## Testing

```sh
sh tests/test_smoke.sh                  # Structural + template-render smoke tests
chezmoi apply --dry-run --verbose       # Dry-run: show every change chezmoi would make
dotfiles check                          # Same as above via the wrapper
```
