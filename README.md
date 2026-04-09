# dotfiles

Personal development environment provisioned with [Ansible](https://docs.ansible.com/).

One command sets up a complete workstation — shell, editor, CLI tools, and config — on macOS or Linux (including WSL2). Idempotent and safe to re-run.

## Quick Start

**First-time setup** on a fresh machine:

```bash
git clone https://github.com/<you>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash bootstrap.sh
```

`bootstrap.sh` installs Ansible if needed, copies the default config, and runs the full playbook.

**After initial setup**, use the CLI wrapper:

```bash
dotfiles install               # Full install (all roles)
dotfiles install zsh neovim    # Install specific roles only
dotfiles update                # Update oh-my-zsh, p10k, Homebrew, nvim plugins
dotfiles doctor                # Verify all tools are installed correctly
dotfiles check                 # Dry-run — preview what would change
dotfiles link                  # Re-create all symlinks
dotfiles edit                  # Open config in $EDITOR
```

> Add `~/.dotfiles/bin` to your `PATH` to use `dotfiles` directly.

## What Gets Installed

| Role | Packages | Package Manager |
|------|----------|-----------------|
| **homebrew** | [Homebrew](https://brew.sh/) | N/A (self-installs) |
| **core** | git, git-lfs, jq, openssh, gpg, curl, wget | System (apt/pacman/brew on mac) |
| **zsh** | zsh, [oh-my-zsh](https://ohmyz.sh/), [powerlevel10k](https://github.com/romkatv/powerlevel10k) | System PM for zsh |
| **cli_tools** | [bat](https://github.com/sharkdp/bat), [eza](https://github.com/eza-community/eza), [lazygit](https://github.com/jesseduffield/lazygit) | Homebrew (default) or system PM |
| **neovim** | [Neovim](https://neovim.io/) 0.11+, [NvChad](https://nvchad.com/) starter | Homebrew (default) or system PM |
| **dotfiles** | Symlinks, git hooks, secrets, alias fixups | N/A |

## Supported Platforms

| Platform | Status |
|----------|--------|
| macOS (Apple Silicon / Intel) | Supported |
| Ubuntu / Debian | Supported |
| Arch Linux / Manjaro | Supported |
| WSL2 | Supported (auto-detected) |
| Fedora | Partial (core + homebrew roles) |

Adding a new distro is just dropping a `<OsFamily>.yml` file in a role's `tasks/` directory — no conditionals to edit.

## Configuration

Copy the example and customize:

```bash
cp group_vars/all.yml.example group_vars/all.yml
```

Key options in `group_vars/all.yml`:

```yaml
# Choose which roles to install (comment out to skip)
default_roles:
  - homebrew
  - core
  - zsh
  - cli_tools
  - neovim
  - dotfiles

# Package manager for dev tools on Linux: "brew" or "system"
pm_preference: brew

# Point to your own NvChad fork after customizing
# nvim_repo: "https://github.com/<you>/nvim-config.git"
```

## Project Structure

```
~/.dotfiles/
├── ansible.cfg                 # Ansible settings
├── inventory                   # Localhost connection
├── site.yml                    # Main playbook
├── group_vars/
│   ├── all.yml                 # Your config (gitignored)
│   └── all.yml.example         # Config template
├── bootstrap.sh                # First-time setup script
├── bin/dotfiles                # CLI wrapper
├── install.sh                  # Thin wrapper → bootstrap.sh
│
├── pre_tasks/                  # Run before all roles
│   ├── detect_wsl.yml          # Sets is_wsl fact
│   ├── detect_brew.yml         # Sets brew_available, brew_prefix
│   └── setup_xdg.yml          # Creates XDG base directories
│
├── roles/
│   ├── homebrew/               # Homebrew install + prerequisites
│   ├── core/                   # System essentials (git, gpg, jq, ssh)
│   ├── zsh/                    # Shell environment
│   ├── cli_tools/              # Modern CLI replacements
│   ├── neovim/                 # Editor + NvChad
│   └── dotfiles/               # Config linking + alias fixups
│
├── zsh/                        # Shell config files
│   ├── zshrc.symlink           # → ~/.zshrc
│   ├── zprofile.symlink        # → ~/.zprofile
│   └── modules/                # Modular zsh config
│       ├── pkg-quarantine.zsh  # Supply-chain security for pip/npm
│       ├── ssh-agent.zsh       # Auto-start ssh-agent
│       └── secrets.zsh         # Load secrets/*.env files
│
├── git/
│   ├── gitconfig.symlink       # → ~/.gitconfig
│   └── hooks/pre-commit        # Secret leak prevention
│
├── tmux/
│   └── tmux.conf.symlink       # → ~/.tmux.conf
│
├── secrets/                    # Credentials (gitignored)
│   ├── credentials.env.example # Template
│   └── credentials.env         # Your secrets (never committed)
│
└── tests/
    ├── test_bootstrap.sh       # Smoke tests (syntax + lint)
    └── molecule/default/       # Docker integration tests
```

## How It Works

### Role Dispatch Pattern

Every role auto-discovers distro-specific tasks:

```yaml
# roles/<role>/tasks/main.yml
- name: Check for distro tasks
  ansible.builtin.stat:
    path: "{{ role_path }}/tasks/{{ ansible_os_family }}.yml"
  register: distro_config

- name: Run distro tasks
  ansible.builtin.include_tasks: "{{ ansible_os_family }}.yml"
  when: distro_config.stat.exists
```

This means the role's `main.yml` stays clean. Platform-specific logic lives in:
- `Debian.yml` — Ubuntu, Debian, Pop!_OS, etc.
- `Archlinux.yml` — Arch, Manjaro, EndeavourOS, etc.
- `Darwin.yml` — macOS

### Symlink Convention

Files named `*.symlink` are automatically linked to `~/.<basename>`:

| Source | Target |
|--------|--------|
| `zsh/zshrc.symlink` | `~/.zshrc` |
| `zsh/zprofile.symlink` | `~/.zprofile` |
| `git/gitconfig.symlink` | `~/.gitconfig` |
| `tmux/tmux.conf.symlink` | `~/.tmux.conf` |

### Alias Fixups

Some distros install CLI tools under different names. The `dotfiles` role creates `~/.local/bin` symlinks to normalize them:

| Distro binary | Alias created |
|---------------|---------------|
| `/usr/bin/batcat` | `~/.local/bin/bat` |
| `/usr/bin/fdfind` | `~/.local/bin/fd` |

This only triggers when the distro binary exists and the standard name is not already in `PATH`.

### Package Manager Strategy

- **System-level packages** (ssh, gpg, git, zsh) always use the system package manager — they integrate with PAM, systemd, and `/etc/shells`.
- **Dev tools** (neovim, bat, eza, lazygit) default to Homebrew for consistent naming and up-to-date versions. Set `pm_preference: system` in `group_vars/all.yml` to use distro packages instead.

## Post-Install Manual Steps

Most things are fully automated. These require one-time manual action:

| Task | Command | Why manual |
|------|---------|-----------|
| Configure powerlevel10k | `p10k configure` | Interactive TUI wizard |
| Import GPG keys | `gpg --import <keyfile>` | Personal key material |
| Generate SSH keys | `ssh-keygen -t ed25519` | Personal key material |
| Fork NvChad config | Clone, customize, set `nvim_repo` | Personal editor preferences |

## Updating

```bash
dotfiles update
```

This runs tasks tagged `update`, which:
- Updates oh-my-zsh via its built-in upgrade script
- Pulls the latest powerlevel10k
- Runs `brew update` (if using Homebrew)
- Runs `:Lazy update` headlessly in neovim

## Testing

```bash
# Syntax and lint checks
bash tests/test_bootstrap.sh

# Dry-run on your machine (shows what would change, changes nothing)
dotfiles check

# Full integration test in Docker containers
molecule test
```

## Adding a New Role

1. Create the role directory:
   ```bash
   mkdir -p roles/myrole/{tasks,defaults}
   ```

2. Write `roles/myrole/defaults/main.yml` with default variables.

3. Write `roles/myrole/tasks/main.yml` with the distro dispatch pattern.

4. Add distro-specific files as needed (e.g., `Debian.yml`, `Darwin.yml`).

5. Add the role name to `default_roles` in `group_vars/all.yml.example`.

## License

Personal configuration. Use as inspiration for your own dotfiles.
