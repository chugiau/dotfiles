# dotfiles

Personal development environment provisioned with [chezmoi](https://www.chezmoi.io/) and [mise](https://mise.jdx.dev/).

One command on a fresh machine sets up shell, editor, CLI tools and config — on macOS, Linux, WSL2, or native Windows. Idempotent and safe to re-run.

## Quick Start

**First-time setup on macOS / Linux / WSL2** — the POSIX bootstrap assumes nothing beyond a POSIX `sh` and network access:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/main/bootstrap.sh)"
```

Or, if you've already cloned the repo:

```sh
git clone https://github.com/<you>/dotfiles.git ~/.dotfiles
sh ~/.dotfiles/bootstrap.sh
```

`bootstrap.sh` installs the system prereqs (curl, git, ca-certs), drops chezmoi and mise into `~/.local/bin`, writes the chezmoi config, and runs `chezmoi apply`. Everything else — the full system package list, `mise install`, oh-my-zsh + powerlevel10k, NvChad starter, git hooks, `chsh -s zsh` — is handled by the chezmoi `run_once_*` scripts.

**First-time setup on native Windows** — run PowerShell as your normal user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
git clone https://github.com/<you>/dotfiles.git $HOME\.dotfiles
pwsh -NoProfile -ExecutionPolicy Bypass -File $HOME\.dotfiles\bootstrap.ps1
```

`bootstrap.ps1` uses winget for native prerequisites (`Git.Git`, `twpayne.chezmoi`, `jdx.mise`), writes the same chezmoi config under `~/.config/chezmoi/chezmoi.toml`, and runs `chezmoi apply`. On Windows, chezmoi deploys a guarded PowerShell profile and PowerShell-native run scripts; the Unix zsh and POSIX run scripts are ignored by `home/.chezmoiignore`.

**After initial setup**, use the CLI wrapper:

```sh
dotfiles install          # Apply chezmoi + install every mise tool
dotfiles update           # Update chezmoi, mise tools, omz, p10k, nvim plugins
dotfiles link             # Re-apply chezmoi (re-create managed files)
dotfiles check            # Dry-run — preview what chezmoi would change
dotfiles doctor           # Verify all tools are present
dotfiles test             # Run smoke, Bats, and optional static checks
dotfiles edit             # Open the repo in $EDITOR
```

> Add `~/.dotfiles/bin` to your `PATH` to use `dotfiles` directly.

On Windows, use the native wrapper:

```powershell
.\bin\dotfiles.ps1 install
.\bin\dotfiles.ps1 doctor
.\bin\dotfiles.ps1 test
```

## What Gets Installed

| Layer | Managed by | Contents |
|---|---|---|
| **System prereqs** | Distro PM (apt / pacman / dnf / brew) | zsh, git, git-lfs, jq, gnupg, pinentry, openssh, ssh-askpass, curl, wget, build tools |
| **Dev tools** | [mise](https://mise.jdx.dev/) | bat, eza, lazygit, glow, ripgrep, node, bun, gh, glab, codex (POSIX/WSL2 only — see below), direnv, bats, ShellCheck, shfmt |
| **Editor binary** | Upstream pre-built tarball | [Neovim](https://neovim.io/) — pinned in `home/run_onchange_after_15-neovim.sh.tmpl`, extracted to `/opt/nvim-<os>-<arch>`, symlinked to `/usr/local/bin/nvim` so `sudoedit` / root / cron all see it |
| **Shell theming** | run_once scripts | [oh-my-zsh](https://ohmyz.sh/), [powerlevel10k](https://github.com/romkatv/powerlevel10k) |
| **Shell autocomplete** | system PM + run_onchange | `bash-completion`, `zsh-syntax-highlighting`, `zsh-autosuggestions` from the distro PM; mise-tool completions generated into `~/.local/share/zsh/completions/` (spec 020) |
| **Editor config** | run_once scripts | [NvChad](https://nvchad.com/) starter |
| **Dotfiles** | [chezmoi](https://www.chezmoi.io/) | zshrc, zprofile, gitconfig, tmux.conf, Claude statusline, ... |

On native Windows, winget covers only native prerequisites and helpers such as Git, chezmoi, mise, PowerShell, Git LFS, GnuPG, age, jq, and oh-my-posh. The shared developer CLI set remains mise-managed through `home/dot_config/mise/config.toml`, except for Codex CLI: mise's `codex` entry excludes native Windows (`os = ["linux", "macos"]`, spec 040), and `home/run_once_after_12-codex-windows.ps1.tmpl` installs it instead through OpenAI's official one-liner — `powershell -ExecutionPolicy ByPass -Command "irm https://chatgpt.com/codex/install.ps1 | iex"` — with no npm, no mise, no package manager in between.

Native Windows also gets its own Claude Code statusline: `home/dot_claude/statusline-command.ps1` and `home/dot_claude/statusline-windows/*.ps1` are a native PowerShell 7+ port of the bash statusline (item-list + packer architecture, spec 021), wired into `~/.claude/settings.json` by `home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl` the same way the Unix path is wired (spec 041).

## Supported Platforms

| Platform | Status |
|---|---|
| macOS (Apple Silicon / Intel) | Supported |
| Ubuntu / Debian / Pop!_OS / Mint | Supported |
| Arch Linux / Manjaro / EndeavourOS | Supported |
| Fedora | Supported |
| WSL2 | Supported (auto-detected via `uname` + `/etc/os-release`) |
| Windows 10/11 + PowerShell | Supported |

Adding a distro is just one new `else if` in `home/run_once_before_10-system-packages.sh.tmpl`.

## Project Structure

```
~/.dotfiles/
├── .chezmoiroot                       # contains "home" — chezmoi source root
├── bootstrap.sh                       # POSIX sh bootstrap (zero-dependency)
├── bootstrap.ps1                      # native Windows bootstrap (winget + chezmoi + mise)
├── bin/dotfiles                       # POSIX sh CLI wrapper
├── bin/dotfiles.ps1                   # native Windows PowerShell CLI wrapper
├── tests/test_smoke.sh                # POSIX sh structural smoke tests
├── tests/windows_smoke.ps1            # Windows PowerShell structural smoke tests
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
    │   ├── executable_statusline-command.sh   # → ~/.claude/statusline-command.sh (POSIX/WSL2)
    │   ├── statusline-command.ps1             # → ~/.claude/statusline-command.ps1 (native Windows)
    │   ├── statusline-windows/                # → ~/.claude/statusline-windows/ (native Windows)
    │   │   ├── Core.ps1
    │   │   ├── Data.ps1
    │   │   ├── Width.ps1
    │   │   ├── Items.ps1
    │   │   └── Layout.ps1
    │   └── hooks/
    │       └── executable_sensitive-file-guard.sh # → ~/.claude/hooks/sensitive-file-guard.sh
    │
    ├── dot_codex/
    │   └── hooks/
    │       └── executable_sensitive-file-guard.sh # → ~/.codex/hooks/sensitive-file-guard.sh
    │
    ├── dot_config/
    │   ├── mise/config.toml                   # → ~/.config/mise/config.toml
    │   └── dotfiles/
    │       ├── powershell/profile.ps1         # → ~/.config/dotfiles/powershell/profile.ps1
    │       ├── bin/
    │       │   └── executable_pinentry-auto      # GUI pinentry with TTY fallback
    │       ├── modules/                       # shell modules sourced by zshrc
    │       │   ├── alias.zsh
    │       │   ├── auth-unlock.zsh
    │       │   ├── functions.zsh
    │       │   ├── fzf.zsh
    │       │   ├── pkg-quarantine.zsh
    │       │   └── ssh-agent.zsh
    │       └── hooks/
    │           └── executable_pre-commit      # plaintext-secret / token scan
    │
    ├── private_dot_gnupg/
    │   └── gpg-agent.conf.tmpl                # → ~/.gnupg/gpg-agent.conf
    │
    ├── Documents/PowerShell/
    │   └── Microsoft.PowerShell_profile.ps1   # → ~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1
    │
    ├── run_once_before_05-windows-packages.ps1.tmpl # winget native prereqs
    ├── run_once_before_10-system-packages.sh.tmpl  # apt/pacman/dnf/brew
    ├── run_onchange_after_10-mise-install.sh.tmpl  # mise install (hash-gated)
    ├── run_onchange_after_11-mise-windows.ps1.tmpl # Windows mise install (hash-gated)
    ├── run_once_after_12-codex-windows.ps1.tmpl    # Windows Codex CLI via official installer
    ├── run_onchange_after_13-claude-statusline-windows.ps1.tmpl # wire Windows Claude statusline
    ├── run_once_after_20-ohmyzsh.sh.tmpl           # omz + powerlevel10k
    ├── run_once_after_30-nvchad.sh.tmpl            # NvChad starter + Lazy sync
    ├── run_onchange_after_40-git-hooks.sh.tmpl     # install repo pre-commit
    ├── run_onchange_after_41-ssh-config-auth.sh.tmpl # append SSH auth defaults
    ├── run_onchange_after_42-gpg-agent-auth.sh.tmpl # restart gpg-agent on config change
    ├── run_once_after_50-default-shell.sh.tmpl     # chsh -s zsh
    ├── run_onchange_after_60-claude-statusline.sh.tmpl # wire Claude statusline
    ├── run_onchange_after_61-claude-env.sh.tmpl    # wire Claude-scoped env
    └── run_onchange_after_62-claude-security.sh.tmpl # wire Claude file guard
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

### Terminal auth unlocks

Interactive shells source `auth-unlock.zsh` before the powerlevel10k instant
prompt. It prepares agent-backed passphrase prompts without prompting during
shell startup:

- GPG gets `GPG_TTY=$(tty)` and `gpg-connect-agent updatestartuptty /bye`, so
  terminal fallback pinentry follows the current terminal or tmux pane.
- `~/.gnupg/gpg-agent.conf` points at the managed `pinentry-auto` wrapper.
  `pinentry-auto` prefers GUI pinentry programs when `DISPLAY` or
  `WAYLAND_DISPLAY` exists, which covers WSLg on WSL2, and falls back to
  `pinentry-curses` / `pinentry-tty` when no GUI session is available.
- GPG cache is bounded to a one hour default TTL and four hour max TTL.
  When that managed config changes, a `run_onchange` script kills the current
  `gpg-agent`; the next GPG operation starts it with the new pinentry and TTL
  settings.
- SSH gets `SSH_ASKPASS` plus `SSH_ASKPASS_REQUIRE=prefer` when a GUI session
  and askpass helper are present, without replacing an explicitly configured
  `SSH_ASKPASS`.
- The same helper is exported as `SUDO_ASKPASS` when unset, so commands that
  deliberately use `sudo -A` can use the GUI prompt and sudo's timestamp cache.
- `ssh-agent` starts with a four hour default identity lifetime. A
  non-destructive `run_onchange` script appends a managed trailing
  `Host *` block to `~/.ssh/config` with `AddKeysToAgent yes`, preserving
  existing host-specific identities while letting encrypted keys unlocked by
  `ssh` enter the cache when not otherwise configured.

This covers the common AI-agent interruption case: a long terminal task reaches
`git commit -S`, `ssh`, or `git push`, a GUI unlock prompt appears for the
human, and successful unlocks are reused for the bounded cache window.

### Tool management via mise

`home/dot_config/mise/config.toml` is the single source of truth for dev tools:

```toml
[tools]
bat     = "latest"
"aqua:eza-community/eza" = "latest"
lazygit = "latest"
glow    = "latest"
ripgrep = "latest"
node    = "lts"
bun     = "latest"
gh      = "latest"
glab    = "latest"
codex   = { version = "latest", os = ["linux", "macos"] }
direnv  = "latest"
bats    = "latest"
shellcheck = "latest"
shfmt      = "latest"
```

> `codex` carries an `os` filter (spec 040) because native Windows does not
> install it through mise, npm, or any other package manager:
> `home/run_once_after_12-codex-windows.ps1.tmpl` runs OpenAI's official
> one-liner instead — `powershell -ExecutionPolicy ByPass -Command "irm
> https://chatgpt.com/codex/install.ps1 | iex"`. `bin/dotfiles.ps1 update`
> re-runs that same one-liner to keep it current, the way `mise upgrade`
> does for every other POSIX-managed tool.

> `direnv` does a p10k-safe startup export before the instant-prompt block,
> then wires its zsh hook in `home/dot_zshrc` after `mise activate`. A global
> `home/dot_config/direnv/direnv.toml` sets `[global] load_dotenv = true` so
> bare `.env` files activate alongside `.envrc`. `direnv allow` is required per
> directory on first entry — that is direnv's security model, not a bug.

> Neovim is **not** managed by mise — it ships from the upstream
> pre-built tarball via `home/run_onchange_after_15-neovim.sh.tmpl` so
> the binary lives on `/usr/local/bin/nvim` and is reachable from
> `sudoedit`, root, and cron without any shell activation.

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

**Claude Code runtime guard.** `home/run_onchange_after_62-claude-security.sh.tmpl` merges a fail-closed runtime policy into `~/.claude/settings.json`: `permissions.deny` hides `~/.ssh/**` and env-like files, `permissions.disableBypassPermissionsMode = "disable"` blocks dangerous permission bypass mode, and `sandbox.enabled` + `sandbox.failIfUnavailable` prevent Bash from silently running without filesystem isolation. The managed `~/.claude/hooks/sensitive-file-guard.sh` also runs on `UserPromptSubmit` and `PreToolUse`, blocking direct references to `~/.ssh/`, `.env`, `.env.*`, `.envrc`, and `*.env*` without echoing the sensitive path in the block reason.

**Codex runtime guard.** `home/run_onchange_after_63-codex-security.sh.tmpl` enables Codex hooks in `~/.codex/config.toml`, writes a `dotfiles-sensitive` filesystem permission profile that allows SSH config files and exact existing `~/.ssh/*.pub` public-key files while blocking unknown SSH filenames and env-like files, and merges `~/.codex/hooks.json` entries for the managed `~/.codex/hooks/sensitive-file-guard.sh`. The hook blocks direct prompt and tool references to env-like files and non-allowlisted `~/.ssh/*` targets without echoing the sensitive path.

## Post-Install Manual Steps

Most things are fully automated. These require one-time manual action:

| Task | Command | Why manual |
|---|---|---|
| Configure powerlevel10k | `p10k configure` | Interactive TUI wizard |
| Approve direnv in a project | `direnv allow` | Required once per directory on first entry (security model) |
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

```powershell
.\bin\dotfiles.ps1 update
```

Runs in order: `chezmoi update`, `mise upgrade`, OpenAI's official
`irm https://chatgpt.com/codex/install.ps1 | iex` one-liner re-run (when
`codex` is on `PATH` — see spec 040), then `nvim --headless "+Lazy! update" +qa`.

## Testing

```sh
# Full local test entrypoint. Runs smoke first, then Bats when installed,
# then optional parse/static gates when their tools are on PATH.
dotfiles test

# Structural smoke tests (POSIX sh, no Bats dependency; chezmoi is optional)
sh tests/test_smoke.sh

# Behaviour tests for shell commands and hooks
bats tests/bats

# Dry-run on your machine — shows what chezmoi would change, changes nothing
dotfiles check
# or:
chezmoi apply --dry-run --verbose
```

```powershell
# Native Windows test entrypoint. Runs Windows smoke first, then POSIX/Bats
# only when those commands exist on PATH.
.\bin\dotfiles.ps1 test

# Windows structural smoke tests; no winget, chezmoi, mise, or network needed.
pwsh -NoProfile -File tests\windows_smoke.ps1
```

`tests/test_smoke.sh` verifies: the source tree layout, POSIX-sh parseability of `bootstrap.sh` and `bin/dotfiles`, bashism absence, Ansible absence, and (if `chezmoi` is on PATH) that every `run_*.sh.tmpl` renders without Go-template errors.

`tests/windows_smoke.ps1` verifies the native Windows structure, parses the
PowerShell bootstrap/profile/run scripts, and checks that the Windows platform
split is represented in `home/.chezmoiignore`.

Bats is the primary behaviour/integration test runner for shell scripts in
this repo. It is intentionally paired with explicit portability gates because
Bats tests run under Bash: keep using `sh -n`, rendered-template parse checks,
`zsh -n`, ShellCheck, and shfmt to catch portability and syntax issues outside
the Bats execution model.

## Adding a Tool

1. Edit `home/dot_config/mise/config.toml`, add the tool line.
2. `dotfiles install` — the hash-gated `run_onchange_after_10-mise-install.sh.tmpl` re-runs and `mise install` picks up the new tool.
3. Optional: add the binary to the `doctor` tool list in `bin/dotfiles`.

## Adding a Managed File

1. Drop the file under `home/` using chezmoi naming (`dot_` prefix, etc).
2. `dotfiles link` — chezmoi deploys it to `$HOME`.

## License

Personal configuration. Use as inspiration for your own dotfiles.
