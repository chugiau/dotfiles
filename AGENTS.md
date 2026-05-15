# Agent Guidelines — dotfiles

This file is for repo-specific agent behavior. Read the relevant files for
implementation details instead of treating this as a README.

## Required Workflow

1. **SDD first.** For non-trivial changes, write/update `specs/NNN-slug.md`
   before tests or code. Template: `## Intent`, `## Acceptance criteria`,
   `## Out of scope`, `## Affected files`. Trivial fixes may put `Spec:` in the
   commit body.
2. **TDD only for code.** Feature/code changes use Red -> Green -> Refactor
   from the spec. Documentation-only changes and other non-code work do not
   require TDD.
3. **Spec wins.** If a spec, test, and implementation disagree, update the test
   and implementation to match the spec, or edit the spec first when behavior
   should change.
4. **Commit each logical unit.** Commit proactively. Spec, test, and
   implementation edits may be separate commits.
5. **English artifacts.** Code, comments, docs, specs, and commits are English.
   User conversation is the only exception.

## Core Commands

`sh bootstrap.sh`, `dotfiles install`, `dotfiles update`, `dotfiles link`,
`dotfiles check`, `dotfiles doctor`, `dotfiles test`, `sh tests/test_smoke.sh`,
`bats tests/bats`. On native Windows use `pwsh -NoProfile -File bootstrap.ps1`,
`pwsh -NoProfile -File bin/dotfiles.ps1 test`, and
`pwsh -NoProfile -File tests/windows_smoke.ps1`.

## Repo Map

- `bootstrap.sh`: POSIX sh bootstrap; installs prereqs, chezmoi, mise, clones
  this repo, writes chezmoi config, runs `chezmoi apply`.
- `bootstrap.ps1`: native Windows bootstrap; uses winget for Git, chezmoi, and
  mise, writes chezmoi config, runs `chezmoi apply`.
- `.chezmoiroot`: points chezmoi at `home/`.
- `home/`: chezmoi source tree, materialized into `$HOME`.
- `bin/dotfiles`: POSIX sh CLI wrapper.
- `bin/dotfiles.ps1`: native Windows PowerShell CLI wrapper.
- `home/dot_config/mise/config.toml`: mise-managed CLI tool manifest.
- `home/dot_config/dotfiles/modules/`: source for shell modules deployed to
  `$DOTFILES/modules/`.
- `home/dot_claude/`, `home/dot_codex/`: managed Claude/Codex hooks and config.
- `tests/test_smoke.sh`: main regression suite; many project decisions are
  encoded as grep/parse/render assertions.

## Easy-To-Guess-Wrong Conventions

- **Runtime/source split:** `$DOTFILES_REPO=~/.dotfiles`; `$DOTFILES=~/.config/dotfiles`.
  Shell startup sources `$DOTFILES`, not repo files. Edit
  `home/dot_config/dotfiles/`, then run `dotfiles link` or `chezmoi apply`.
- **Windows runtime split:** PowerShell loads
  `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`, which only sources
  `$HOME/.config/dotfiles/powershell/profile.ps1`. Keep Windows startup logic in
  `home/dot_config/dotfiles/powershell/`.
- **Shell file split:** `dot_zshenv.tmpl` is pure env for every zsh invocation.
  Put login side effects in `dot_zprofile`; interactive setup in `dot_zshrc`.
- **BROWSER is apply-time:** `dot_zshenv.tmpl` renders `open`, `wslview`, or
  `xdg-open`; do not add per-shell detection.
- **mise PATH order matters:** bun/dotnet fallback blocks append to `PATH`.
  `mise activate zsh` stays after them; `direnv hook zsh` stays after mise.
- **Neovim is not mise-managed:** `run_onchange_after_15-neovim.sh.tmpl`
  installs `/opt/nvim-<os>-<arch>` and `/usr/local/bin/nvim`. Do not add
  `neovim` to mise.
- **pnpm is retired:** bun is the mise-managed JS package manager. Do not
  restore `PNPM_HOME`, pnpm completions, or a pnpm tool entry.
- **direnv loads bare `.env`:** `direnv.toml` sets `[global] load_dotenv = true`;
  `direnv allow` is still required.
- **Secrets are chezmoi-native:** no `secrets.zsh`. Use `encrypted_` age files
  or `.env.tmpl`; pre-commit blocks plaintext `*.env`, `key.txt`, `*.age`, and
  common provider tokens.
- **Claude and Codex guards differ:** Claude broadly blocks `.ssh` and env-like
  references. Codex allows `~/.ssh/config`, `~/.ssh/config.d/*`, and top-level
  `~/.ssh/*.pub`; it blocks SSH directories, unknown SSH filenames, and env-like
  targets. Do not echo sensitive paths.
- **Codex filesystem allowlist is exact:** write exact existing public-key paths,
  not `~/.ssh/*.pub` globs.
- **Codex hooks config:** use `[features].hooks = true`; remove/migrate
  deprecated `codex_hooks`.
- **Completion wiring is layered:** system packages, generated user-scope
  completions, `completions.zsh` before oh-my-zsh, `bashcompinit` after compinit.
- **Some personal environment hooks are intentional:** WSL2 Docker completion
  cleanup, fcitx5 login setup, auth unlock/pinentry behavior, peon-ping aliases,
  and Claude/Codex runtime policies are deliberate unless the relevant spec
  changes first.
- **Windows chezmoi split:** `home/.chezmoiignore` keeps Unix run scripts out of
  native Windows applies and keeps Windows PowerShell files out of Unix applies.
  Update it when adding platform-specific run scripts.

## Testing Notes

- `dotfiles test` is the full local entrypoint; `tests/test_smoke.sh` is the
  main suite for structure, rendered templates, parse gates, and spec decisions.
- On native Windows, `bin/dotfiles.ps1 test` runs `tests/windows_smoke.ps1` and
  skips POSIX/Bats checks when `sh` or `bats` are not installed.
- Bats runs under Bash; pair it with `sh -n`, rendered template checks, `zsh -n`,
  ShellCheck, and shfmt where relevant.
- Documentation-only AGENTS edits do not need a test run unless they change
  command names, file paths, or documented test expectations.
