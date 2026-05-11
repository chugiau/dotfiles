# Agent Guidelines — dotfiles

## Rules (override defaults)

1. **SDD (Spec-Driven Development)** — Write a spec **before** the test. Workflow is **Spec → Test → Code**: the spec defines *what* and *why* (intent, acceptance criteria, out-of-scope, affected files); the test encodes the spec as an executable check; the code makes the test pass. The spec is the source of truth — if behaviour needs to change, edit the spec first, then the test, then the code. Never let test or code drift ahead of the spec.
   - **Where specs live.** Non-trivial change → `specs/NNN-slug.md` (committed alongside the code change). Trivial fix (typo, one-liner, doc tweak) → spec may live inline in the commit message body under a `Spec:` section. When in doubt, write the file.
   - **Spec template.** `## Intent` · `## Acceptance criteria` (bulleted, each one testable) · `## Out of scope` · `## Affected files`.
   - **Interaction with TDD.** SDD does *not* replace TDD — it precedes it. Red-Green-Refactor still applies; the spec just answers "red against what?" before you write the failing test. If a spec and an existing test conflict, the spec wins: update the test.
2. **TDD** — Write tests first, derived from the spec. Red → Green → Refactor.
3. **Commit after each logical unit** — Don't batch. Commit proactively without waiting to be asked. A spec edit, a test edit, and an implementation edit are each a logical unit and may be separate commits.
4. **English for all artifacts** — Code, commits, comments, docs, specs. User conversation is the only exception.

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
dotfiles test         # Smoke + Bats + optional static checks
```

## Architecture

- **`bootstrap.sh`** — POSIX sh, zero-dependency bootstrap. Installs curl/git/ca-certs via system PM, drops chezmoi and mise into `~/.local/bin`, clones the repo, writes `~/.config/chezmoi/chezmoi.toml`, runs `chezmoi apply`.
- **`.chezmoiroot`** — contains `home`. Points chezmoi at `home/` as its source directory.
- **`home/`** — chezmoi source root, mirrors `$HOME`. File naming follows chezmoi conventions (`dot_`, `executable_`, `private_`, `encrypted_`, `run_once_*`, `run_onchange_*`).
- **`home/dot_config/mise/config.toml`** — mise tool manifest (neovim, bat, eza, lazygit, glow).
- **`home/dot_config/dotfiles/`** — runtime tree deployed by chezmoi:
  - `modules/*.zsh` — shell modules sourced by zshrc (alias, functions, fzf, pkg-quarantine, ssh-agent)
  - `hooks/pre-commit` — source for the repo's own git pre-commit hook (blocks plaintext env files, age keys, and leaked provider tokens)
- **`home/dot_claude/`** — Claude Code runtime assets:
  - `statusline-command.sh` and `statusline/` — managed statusline
  - `hooks/sensitive-file-guard.sh` — blocks prompt/tool references to `~/.ssh/` and env-like files before Claude processes or executes them
- **`home/dot_codex/`** — Codex runtime assets:
  - `hooks/sensitive-file-guard.sh` — blocks prompt/tool references to `~/.ssh/` and env-like files before Codex continues
- **`home/run_once_*.sh.tmpl`** — chezmoi setup scripts (system packages, mise install, oh-my-zsh + p10k, NvChad, git hooks, chsh).
- **`bin/dotfiles`** — POSIX sh CLI wrapper around chezmoi + mise, including `secrets-init` for age setup.
- **`tests/test_smoke.sh`** — POSIX sh structural tests + chezmoi template render checks.
- **`tests/bats/`** — Bats behaviour/integration tests for shell commands and hooks.

## Environment variables

| Variable         | Points at                | Purpose                                     |
|------------------|--------------------------|---------------------------------------------|
| `$DOTFILES_REPO` | `$HOME/.dotfiles`        | Git checkout                                |
| `$DOTFILES`      | `$HOME/.config/dotfiles` | chezmoi runtime tree — shell modules, hooks |

zshrc sources `$DOTFILES/modules/*.zsh`, so editing the source in `home/dot_config/dotfiles/modules/` and re-running `dotfiles link` redeploys it.

## chezmoi run_once flow

Ordering uses numeric prefixes:

| Script                                       | Phase        | Trigger                            |
|----------------------------------------------|--------------|------------------------------------|
| `run_once_before_10-system-packages.sh.tmpl` | before apply | once                               |
| `run_onchange_after_10-mise-install.sh.tmpl` | after apply  | whenever mise config hash changes  |
| `run_once_after_20-ohmyzsh.sh.tmpl`          | after apply  | once                               |
| `run_once_after_30-nvchad.sh.tmpl`           | after apply  | once                               |
| `run_onchange_after_40-git-hooks.sh.tmpl`    | after apply  | whenever hook content hash changes |
| `run_onchange_after_41-ssh-config-auth.sh.tmpl` | after apply | whenever ssh-agent module hash changes |
| `run_onchange_after_42-gpg-agent-auth.sh.tmpl` | after apply | whenever gpg-agent config hash changes |
| `run_once_after_50-default-shell.sh.tmpl`    | after apply  | once                               |
| `run_onchange_after_60-claude-statusline.sh.tmpl` | after apply | whenever statusline wireup changes |
| `run_onchange_after_61-claude-env.sh.tmpl`   | after apply  | whenever Claude env wireup changes |
| `run_onchange_after_62-claude-security.sh.tmpl` | after apply | whenever Claude sensitive-file policy changes |
| `run_onchange_after_63-codex-security.sh.tmpl` | after apply | whenever Codex sensitive-file policy changes |

Go templates dispatch on `.chezmoi.os` (`darwin` / `linux`) and `.chezmoi.osRelease.id` (`ubuntu` / `debian` / `arch` / `fedora` / …).

## Adding a distro

Edit `home/run_once_before_10-system-packages.sh.tmpl` — add a new `install_<distro>()` function and an `else if` branch in the Go-template dispatch block. No other file to touch.

## Adding a tool

1. Edit `home/dot_config/mise/config.toml`, add the tool line.
2. `dotfiles install` — the content hash in `run_onchange_after_10-mise-install.sh.tmpl` changes, chezmoi re-runs it, mise picks up the new tool.
3. Optional: add the binary name to the `doctor` loop in `bin/dotfiles`.

## Secrets

Two chezmoi-native routes, no bespoke loader:

- **age-encrypted files.** `dotfiles secrets-init` (idempotent) generates `~/.config/chezmoi/key.txt` and appends the `[age]` block to `chezmoi.toml`. Add files with `chezmoi add --encrypt <path>`; the source file is stored under an `encrypted_` prefix (ciphertext, safe to commit). The `age` package is installed on every distro branch of `run_once_before_10-system-packages.sh.tmpl`.
- **Bitwarden (or other password managers) via templates.** A `*.env.tmpl` file can call chezmoi's built-in `{{ bitwardenFields "item" "name" }}` (or `onepassword`, `pass`, `keyring`, …) at apply time. Nothing secret lives in the repo — chezmoi refetches on every `apply`. Requires the chosen CLI to be installed and unlocked.

The pre-commit hook at `home/dot_config/dotfiles/hooks/executable_pre-commit` blocks staged plaintext `*.env` (unless the path has `encrypted_` or the file ends `.env.tmpl`), age private keys (`key.txt`, `*.age`), and a bank of provider-token regexes.

The Claude Code runtime guard at `home/dot_claude/hooks/executable_sensitive-file-guard.sh` blocks direct prompt and tool references to `~/.ssh/`, `.env`, `.env.*`, `.envrc`, and `*.env*` without echoing the matched path. `home/run_onchange_after_62-claude-security.sh.tmpl` wires that hook into `UserPromptSubmit` and `PreToolUse`, adds matching `permissions.deny` entries, disables bypass permissions mode, and enables fail-closed sandboxing so Bash cannot silently read denied paths without filesystem isolation.

The Codex runtime guard at `home/dot_codex/hooks/executable_sensitive-file-guard.sh` blocks direct prompt and tool references to `~/.ssh/`, `.env`, `.env.*`, `.envrc`, and `*.env*` without echoing the matched path. `home/run_onchange_after_63-codex-security.sh.tmpl` enables Codex hooks, merges matching `~/.codex/hooks.json` entries, and writes a `dotfiles-sensitive` filesystem permission profile that denies reads for `~/.ssh/**` and env-like files.

## Testing

```sh
sh tests/test_smoke.sh                  # Structural + template-render smoke tests
bats tests/bats                         # Behaviour tests (after mise install)
dotfiles test                           # Full local test entrypoint
chezmoi apply --dry-run --verbose       # Dry-run: show every change chezmoi would make
dotfiles check                          # Same as above via the wrapper
```

Bats is the primary behaviour/integration test runner. It does not prove POSIX
or zsh portability because Bats tests run under Bash, so pair Bats coverage
with explicit parse/static gates (`sh -n`, rendered chezmoi templates, `zsh -n`,
ShellCheck, and shfmt when available).
