# 004 — Shell profile split: zshenv / zprofile / zshrc by purpose

## Intent

The current `home/dot_zprofile` and `home/dot_zshrc` mix three concerns that
zsh keeps in three separate files for a reason:

- **`~/.zshenv`** runs on *every* zsh invocation (login, non-login,
  interactive, non-interactive, scripts, `ssh host 'cmd'`). Pure env
  exports that every child process should inherit live here.
- **`~/.zprofile`** runs once per login shell, before `~/.zshrc`. Login-
  scoped side effects and env whose cost shouldn't be paid per subshell
  (fcitx5 daemon startup, Homebrew `shellenv`) live here.
- **`~/.zshrc`** runs on every interactive shell. Anything the user will
  actually see or type at — prompt, key bindings, aliases, completions,
  `mise activate`, shell-integration evals — lives here.

Three classes of drift to correct:

1. `dot_zprofile` exports `DOTFILES_REPO`, `DOTFILES`, `EDITOR`, `VISUAL`,
   `BROWSER`, `DOTNET_CLI_TELEMETRY_OPTOUT`, and prepends `$HOME/bin` +
   `$HOME/.local/bin` to `$PATH`. None of those are login-scoped; a
   `zsh -c` subshell or `ssh host 'cmd'` today misses them entirely. They
   belong in `~/.zshenv`.

2. `dot_zprofile` sets six input-method env vars and starts `fcitx5 -d`
   unconditionally. On any machine without fcitx5 (including this WSL
   box), every login prints a "command not found" error. The IM env
   vars + the daemon launch must be guarded on `command -v fcitx5`, the
   daemon must not be relaunched when one is already running, and the
   existing `SDL_IM_MODULE=icitx` typo (line 18) must be fixed to
   `fcitx`.

3. `dot_zprofile` exports `ENABLE_LSP_TOOL=1` to leak a Claude-Code-only
   flag into every login shell's environment. Claude Code reads env
   injections from `~/.claude/settings.json`'s top-level `env` object, so
   the flag belongs there instead — scoped to Claude Code subprocesses,
   invisible to anything else. The wireup follows the same
   chezmoi-run_onchange + jq merge pattern that already powers the
   statusline script (`run_onchange_after_60-claude-statusline.sh.tmpl`).

4. `dot_zshrc` carries two leftovers that don't belong in an interactive
   rc file: (a) the base `$HOME/bin:$HOME/.local/bin:/usr/local/bin`
   `$PATH` prepend, which is env bootstrapping; and (b) the Homebrew
   `shellenv` loop, which is login-scoped env per Homebrew's own install
   script. Both migrate out: (a) into `dot_zshenv`, (b) into
   `dot_zprofile`. Separately, the 100-line stock oh-my-zsh commented
   boilerplate (roughly `CASE_SENSITIVE` through `HIST_STAMPS`) is
   cruft from the original `oh-my-zsh/tools/install.sh` template that
   has never been edited and can be trimmed to the four lines actually
   in use (`ZSH=`, `ZSH_THEME=`, `plugins=`, `source $ZSH/oh-my-zsh.sh`).

## Acceptance criteria

### `home/dot_zshenv` (new file)

- Exports `DOTFILES_REPO="$HOME/.dotfiles"`.
- Exports `DOTFILES="$HOME/.config/dotfiles"`.
- Exports `EDITOR="nvim"` and `VISUAL="nvim"`.
- Exports `BROWSER="brave.exe"`.
- Exports `DOTNET_CLI_TELEMETRY_OPTOUT=1`.
- Prepends `$HOME/bin:$HOME/.local/bin` to `$PATH`.
- Prepends `$DOTFILES_REPO/shellscripts` to `$PATH` (matches the
  current `dot_zprofile` line).

### `home/dot_zprofile`

- No longer exports `DOTFILES_REPO`, `DOTFILES`, `EDITOR`, `VISUAL`,
  `BROWSER`, `DOTNET_CLI_TELEMETRY_OPTOUT`, or the base `$PATH` prepends.
  Those live in `dot_zshenv`.
- No longer exports `ENABLE_LSP_TOOL`. That moves into
  `~/.claude/settings.json` via the new run_onchange script below.
- Wraps the input-method env vars and the `fcitx5 -d` launch in
  `command -v fcitx5`, so a machine without fcitx5 sets nothing and
  launches nothing.
- `SDL_IM_MODULE=icitx` typo is corrected to `SDL_IM_MODULE=fcitx`.
- Does not start a second fcitx5 daemon when one is already running
  (guarded by `pgrep -x fcitx5` or equivalent).
- Receives the Homebrew `shellenv` loop from `dot_zshrc`, covering
  macOS (`/opt/homebrew`, `/usr/local`) and Linuxbrew
  (`/home/linuxbrew/.linuxbrew`) layouts; machines without brew skip
  the `eval` entirely.

### `home/dot_zshrc`

- No longer contains `export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH`
  or any equivalent base `$PATH` bootstrap. `dot_zshenv` runs first and
  handles that.
- No longer contains the Homebrew `shellenv` loop. It moves to
  `dot_zprofile`.
- The stock oh-my-zsh commented boilerplate is trimmed. Concretely, the
  following marker strings must be absent: `CASE_SENSITIVE`,
  `HYPHEN_INSENSITIVE`, `DISABLE_MAGIC_FUNCTIONS`, `DISABLE_LS_COLORS`,
  `DISABLE_AUTO_TITLE`, `ENABLE_CORRECTION`, `COMPLETION_WAITING_DOTS`,
  `DISABLE_UNTRACKED_FILES_DIRTY`, `HIST_STAMPS`, `ZSH_CUSTOM`,
  `ZSH_THEME_RANDOM_CANDIDATES`. The four active lines stay: `ZSH=`,
  `ZSH_THEME=`, `plugins=`, `source $ZSH/oh-my-zsh.sh`.
- Still activates mise, still loads p10k and oh-my-zsh, still sources
  the `$DOTFILES/modules/*.zsh` modules, still carries the
  guarded per-tool blocks (tofu / fnm / pnpm / dotnet / bun) from
  spec 003.

### `home/run_onchange_after_61-claude-env.sh.tmpl` (new file)

- POSIX sh, modelled on `run_onchange_after_60-claude-statusline.sh.tmpl`.
- Skips gracefully with a log line when `jq` is missing.
- Creates `~/.claude/settings.json` as `{}` if it does not already exist.
- Uses `jq` to set `.env.ENABLE_LSP_TOOL = "1"` without disturbing any
  other `.env.*` key or any unrelated top-level key (`statusLine`,
  `hooks`, `permissions`, `autoMemoryEnabled`, …).
- Idempotent: a second run in a row leaves `settings.json`'s mtime
  untouched.

## Out of scope

- Deleting `zmodload zsh/zprof` from `dot_zshrc`. It's a profiler hook,
  harmless, and may be intentional.
- Restructuring the OpenSpec `fpath` + early `compinit` block near the
  top of `dot_zshrc`. Reordering it risks breaking p10k instant prompt.
- Moving per-tool env exports (`FNM_PATH`, `PNPM_HOME`, `DOTNET_ROOT`,
  `BUN_INSTALL`) into `dot_zshenv`. They live inside guarded blocks that
  also run interactive-only side effects (completion generation), so
  they stay co-located in `dot_zshrc`.
- Moving `ssh-agent.zsh` sourcing or the Docker Desktop WSL2
  `vendor-completions` fpath hack. Both are correct where they are.
- Removing `~/.dotnet/corefx` user-owned state.
- Generalising the `run_onchange_after_60-claude-statusline.sh.tmpl`
  script to cover both statusLine and env in one pass. A sister script
  keeps each wireup on its own content-hash lifecycle.

## Affected files

- `specs/004-shell-profile-split.md` (new)
- `home/dot_zshenv` (new)
- `home/dot_zprofile` (rewritten)
- `home/dot_zshrc` (trim)
- `home/run_onchange_after_61-claude-env.sh.tmpl` (new)
- `tests/test_smoke.sh` (new assertions)
