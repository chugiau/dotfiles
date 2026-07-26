# Agent Guidelines — dotfiles

Personal cross-platform dotfiles: chezmoi renders `home/` into `$HOME`, mise
manages the CLI toolchain, and POSIX sh plus PowerShell wrappers drive the rest.

This file covers what is easy to get wrong here. Read the files themselves for
implementation details, `README.md` for the architecture guide, and `specs/` for
why a decision is what it is.

## Required Workflow

1. **Spec first.** Non-trivial changes get a `specs/NNN-slug.md` with
   `## Intent`, `## Acceptance criteria`, `## Out of scope`, `## Affected
   files`; the newest specs are the reference for depth and tone. Trivial fixes
   may put `Spec:` in the commit body instead.
2. **TDD for code only.** Feature and code changes run Red -> Green -> Refactor
   from the spec. Documentation and other non-code work does not.
3. **The spec is the tiebreaker.** When spec, test, and implementation disagree,
   change the test and implementation — or edit the spec first when the behavior
   itself should change.
4. **Commit each logical unit.** Commit proactively; spec, test, and
   implementation edits may be separate commits.
5. **Artifacts are English.** Code, comments, docs, specs, commits. Only the
   conversation with the user follows their language.

## Commands And Tests

`dotfiles test` is the local gate: it runs `tests/test_smoke.sh` plus
`bats tests/bats` (Bats runs under Bash). Other entrypoints are
`sh bootstrap.sh` and `dotfiles install|update|link|check|doctor`. Native
Windows uses `pwsh -NoProfile -File bootstrap.ps1` and
`pwsh -NoProfile -File bin/dotfiles.ps1 test`, which runs
`tests/windows_smoke.ps1` and skips POSIX and Bats checks when `sh` or `bats`
are missing.

`tests/test_smoke.sh` is more than a smoke test: project decisions are frozen
there as grep, parse, and rendered-template assertions, so a seemingly unrelated
edit can still fail it. Freeze new spec decisions the same way, and pair Bats
with `sh -n`, `zsh -n`, ShellCheck, and shfmt where they apply.

Documentation-only edits do not need a test run unless they change command
names, file paths, or documented test expectations.

## Easy-To-Guess-Wrong Conventions

- **Runtime/source split:** `$DOTFILES_REPO=~/.dotfiles`; `$DOTFILES=~/.config/dotfiles`.
  Shell startup sources `$DOTFILES`, not repo files. Edit
  `home/dot_config/dotfiles/` — shell modules live in its `modules/` — then run
  `dotfiles link` or `chezmoi apply`.
- **Windows runtime split:** PowerShell loads
  `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`, which only sources
  `$HOME/.config/dotfiles/powershell/profile.ps1`. Keep Windows startup logic in
  `home/dot_config/dotfiles/powershell/`.
- **Shell file split:** `dot_zshenv.tmpl` is pure env for every zsh invocation.
  Put login side effects in `dot_zprofile`; interactive setup in `dot_zshrc`.
- **BROWSER is apply-time:** `dot_zshenv.tmpl` renders `open`, `wslview`, or
  `xdg-open`; do not add per-shell detection.
- **CLI tools come from mise:** add them to
  `home/dot_config/mise/config.toml`, with the exceptions below.
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
