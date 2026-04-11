# dotfiles

Personal development environment provisioned with [chezmoi](https://www.chezmoi.io/) and [mise](https://mise.jdx.dev/).

One command on a fresh machine sets up shell, editor, CLI tools and config — on macOS or Linux (including WSL2). Idempotent and safe to re-run.

## Quick Start

**First-time setup** on a fresh machine — the bootstrap script assumes nothing beyond a POSIX `sh` and network access:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/main/bootstrap.sh)"
```

Or, if you've already cloned the repo:

```sh
git clone https://github.com/<you>/dotfiles.git ~/.dotfiles
sh ~/.dotfiles/bootstrap.sh
```

`bootstrap.sh` installs the system prereqs (curl, git, ca-certs), drops chezmoi and mise into `~/.local/bin`, writes the chezmoi config, and runs `chezmoi apply`. Everything else — the full system package list, `mise install`, oh-my-zsh + powerlevel10k, NvChad starter, git hooks, `chsh -s zsh` — is handled by the chezmoi `run_once_*` scripts.

**After initial setup**, use the CLI wrapper:

```sh
dotfiles install          # Apply chezmoi + install every mise tool
dotfiles update           # Update chezmoi, mise tools, omz, p10k, nvim plugins
dotfiles link             # Re-apply chezmoi (re-create managed files)
dotfiles check            # Dry-run — preview what chezmoi would change
dotfiles doctor           # Verify all tools are present
dotfiles edit             # Open the repo in $EDITOR
```

> Add `~/.dotfiles/bin` to your `PATH` to use `dotfiles` directly.

## What Gets Installed

| Layer | Managed by | Contents |
|---|---|---|
| **System prereqs** | Distro PM (apt / pacman / dnf / brew) | zsh, git, git-lfs, jq, gnupg, openssh, curl, wget, build tools |
| **Dev tools** | [mise](https://mise.jdx.dev/) | neovim, bat, eza, lazygit, glow |
| **Shell theming** | run_once scripts | [oh-my-zsh](https://ohmyz.sh/), [powerlevel10k](https://github.com/romkatv/powerlevel10k) |
| **Editor config** | run_once scripts | [NvChad](https://nvchad.com/) starter |
| **Dotfiles** | [chezmoi](https://www.chezmoi.io/) | zshrc, zprofile, gitconfig, tmux.conf, Claude statusline, ... |

## Supported Platforms

| Platform | Status |
|---|---|
| macOS (Apple Silicon / Intel) | Supported |
| Ubuntu / Debian / Pop!_OS / Mint | Supported |
| Arch Linux / Manjaro / EndeavourOS | Supported |
| Fedora | Supported |
| WSL2 | Supported (auto-detected via `uname` + `/etc/os-release`) |

Adding a distro is just one new `else if` in `home/run_once_before_10-system-packages.sh.tmpl`.

## Project Structure

```
~/.dotfiles/
├── .chezmoiroot                       # contains "home" — chezmoi source root
├── bootstrap.sh                       # POSIX sh bootstrap (zero-dependency)
├── bin/dotfiles                       # POSIX sh CLI wrapper
├── tests/test_smoke.sh                # POSIX sh structural smoke tests
│
└── home/                              # chezmoi source — mirrors $HOME
    ├── .chezmoiignore
    │
    ├── dot_zshrc                      # → ~/.zshrc
    ├── dot_zprofile                   # → ~/.zprofile
    ├── dot_gitconfig                  # → ~/.gitconfig
    ├── dot_gitignore                  # → ~/.gitignore
    ├── dot_tmux.conf                  # → ~/.tmux.conf
    │
    ├── dot_claude/
    │   └── executable_statusline-command.sh   # → ~/.claude/statusline-command.sh
    │
    ├── dot_config/
    │   ├── mise/config.toml                   # → ~/.config/mise/config.toml
    │   └── dotfiles/
    │       ├── modules/                       # shell modules sourced by zshrc
    │       │   ├── alias.zsh
    │       │   ├── functions.zsh
    │       │   ├── fzf.zsh
    │       │   ├── pkg-quarantine.zsh
    │       │   └── ssh-agent.zsh
    │       └── hooks/
    │           └── executable_pre-commit      # plaintext-secret / token scan
    │
    ├── run_once_before_10-system-packages.sh.tmpl  # apt/pacman/dnf/brew
    ├── run_onchange_after_10-mise-install.sh.tmpl  # mise install (hash-gated)
    ├── run_once_after_20-ohmyzsh.sh.tmpl           # omz + powerlevel10k
    ├── run_once_after_30-nvchad.sh.tmpl            # NvChad starter + Lazy sync
    ├── run_onchange_after_40-git-hooks.sh.tmpl     # install repo pre-commit
    └── run_once_after_50-default-shell.sh.tmpl     # chsh -s zsh
```

## How It Works

### chezmoi layout conventions

Files under `home/` follow [chezmoi's naming conventions](https://www.chezmoi.io/reference/source-state-attributes/):

| Prefix | Meaning |
|---|---|
| `dot_` | Leading `.` on the destination (e.g. `dot_zshrc` → `~/.zshrc`) |
| `executable_` | Mark the destination mode as `+x` |
| `private_` | Mark the destination mode as `0600` |
| `run_once_before_*.sh.tmpl` | POSIX sh script, runs once, before `apply` |
| `run_once_after_*.sh.tmpl`  | POSIX sh script, runs once, after `apply` |
| `run_onchange_*.sh.tmpl` | Re-runs when the rendered script content changes |

`.chezmoiroot` at the repo root points chezmoi at `home/` as its source directory, keeping the top level reserved for `bootstrap.sh`, `bin/`, `tests/`, and docs.

### $DOTFILES runtime tree

The shell ships with two environment variables:

| Variable | Points at | Purpose |
|---|---|---|
| `$DOTFILES_REPO` | `$HOME/.dotfiles` | Git checkout — used by `bin/dotfiles`, git hooks, tooling |
| `$DOTFILES` | `$HOME/.config/dotfiles` | chezmoi-deployed runtime tree — shell modules sourced by zshrc/zprofile |

Splitting the two keeps source and runtime separate: `zshrc` sources `$DOTFILES/modules/*.zsh`, which are the materialised files chezmoi drops into the runtime tree. Editing the source file in `home/dot_config/dotfiles/modules/` and re-running `dotfiles link` re-deploys it.

### Tool management via mise

`home/dot_config/mise/config.toml` is the single source of truth for dev tools:

```toml
[tools]
neovim  = "latest"
bat     = "latest"
eza     = "latest"
lazygit = "latest"
glow    = "latest"
```

Add or remove a tool, run `dotfiles install`, and mise picks up the change. The `run_onchange_after_10-mise-install.sh.tmpl` script has the config's SHA256 hash embedded in a comment, so chezmoi re-runs `mise install` automatically when the manifest is edited.

### Secrets

Two complementary mechanisms, both driven by chezmoi itself — there is no bespoke loader.

**A. Encrypted files with [age](https://github.com/FiloSottile/age).** Real secret files ship as ciphertext in this very repo under an `encrypted_` prefix and are transparently decrypted on `chezmoi apply`. One-time setup on each machine:

```sh
dotfiles secrets-init
```

The subcommand is idempotent. It:

1. Verifies `age-keygen` is on `PATH` (installed via the system package step of `run_once_before_10-system-packages.sh.tmpl`).
2. Generates `~/.config/chezmoi/key.txt` if missing (never overwrites).
3. Appends the `encryption = "age"` + `[age]` block to `~/.config/chezmoi/chezmoi.toml` if not already present.

After the first run, adding a new encrypted file is a single chezmoi command:

```sh
chezmoi add --encrypt ~/.config/dotfiles/credentials.env
# Stores home/encrypted_private_dot_config/dotfiles/credentials.env (ciphertext)
chezmoi edit ~/.config/dotfiles/credentials.env  # opens decrypted in $EDITOR
```

Back up `~/.config/chezmoi/key.txt` to your password manager — without it, encrypted files in the repo cannot be decrypted on a new machine.

**B. Runtime pulls from [Bitwarden](https://bitwarden.com/).** For items already stored in a password manager, create a chezmoi template instead of committing ciphertext. Example (`home/private_dot_config/dotfiles/credentials.env.tmpl`):

```
# chezmoi renders this on apply; requires `bw` CLI logged in and unlocked.
OPENAI_API_KEY={{ (bitwardenFields "item" "My OpenAI Key").api_key.value }}
GITHUB_TOKEN={{ (bitwardenFields "item" "gh pat dotfiles").token.value }}
```

The repo holds only the template — no ciphertext, no cleartext. Every `chezmoi apply` refreshes the rendered file by pulling live from Bitwarden. Install the `bw` CLI (`npm install -g @bitwarden/cli` or system package) and run `bw login && bw unlock` before applying. Chezmoi also supports `onepassword`, `pass`, `keepassxc`, `keyring`, and more — see [chezmoi password managers](https://www.chezmoi.io/user-guide/password-managers/).

**Pre-commit guard.** `home/dot_config/dotfiles/hooks/executable_pre-commit` (installed as the repo's own `.git/hooks/pre-commit` by `run_onchange_after_40-git-hooks.sh.tmpl`) blocks any plaintext `*.env` file that is neither `encrypted_` prefixed nor a `.env.tmpl` template, rejects staged age private keys (`key.txt`, `*.age`), and scans the staged diff for common provider token patterns (GitLab, GitHub PAT/OAuth/App, OpenAI, AWS, Slack).

## Post-Install Manual Steps

Most things are fully automated. These require one-time manual action:

| Task | Command | Why manual |
|---|---|---|
| Configure powerlevel10k | `p10k configure` | Interactive TUI wizard |
| Initialise age encryption | `dotfiles secrets-init` | Generates `~/.config/chezmoi/key.txt` and wires chezmoi.toml |
| Add an encrypted secret file | `chezmoi add --encrypt ~/.config/dotfiles/credentials.env` | Per-user content |
| Log into Bitwarden (for `bw`-driven templates) | `bw login && bw unlock` | Requires interactive master password |
| Import GPG keys | `gpg --import <keyfile>` | Personal key material |
| Generate SSH keys | `ssh-keygen -t ed25519` | Personal key material |
| Fork NvChad config | Clone, customise, point `run_once_after_30-nvchad.sh.tmpl` at your fork | Personal editor preferences |

## Updating

```sh
dotfiles update
```

Runs in order:
- `chezmoi update` — pulls the repo and re-applies any changed source files
- `mise upgrade` — bumps every managed tool to its latest version
- `oh-my-zsh` `upgrade.sh` — pulls oh-my-zsh
- `git -C powerlevel10k pull` — bumps p10k
- `nvim --headless "+Lazy! update" +qa` — refreshes neovim plugins

## Testing

```sh
# Structural smoke tests (POSIX sh, no dependencies beyond chezmoi if present)
sh tests/test_smoke.sh

# Dry-run on your machine — shows what chezmoi would change, changes nothing
dotfiles check
# or:
chezmoi apply --dry-run --verbose
```

`tests/test_smoke.sh` verifies: the source tree layout, POSIX-sh parseability of `bootstrap.sh` and `bin/dotfiles`, bashism absence, Ansible absence, and (if `chezmoi` is on PATH) that every `run_*.sh.tmpl` renders without Go-template errors.

## Adding a Tool

1. Edit `home/dot_config/mise/config.toml`, add the tool line.
2. `dotfiles install` — the hash-gated `run_onchange_after_10-mise-install.sh.tmpl` re-runs and `mise install` picks up the new tool.
3. Optional: add the binary to the `doctor` tool list in `bin/dotfiles`.

## Adding a Managed File

1. Drop the file under `home/` using chezmoi naming (`dot_` prefix, etc).
2. `dotfiles link` — chezmoi deploys it to `$HOME`.

## License

Personal configuration. Use as inspiration for your own dotfiles.
