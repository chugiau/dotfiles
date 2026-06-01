# 036 - mise IDE integration

## Intent

IDEs and editors do not behave like interactive shells. If an editor is
launched from a desktop session, launcher, or IDE-managed process tree, it may
not inherit the interactive `mise activate zsh` environment from
`~/.zshrc`. Language plugins then fail to find mise-managed tools such as
`node`, `bun`, `gh`, `glab`, or `codex` even though those tools work in an
interactive terminal.

Follow mise's IDE integration guidance by exposing mise shims from the login
profile. Shims are the right default for IDEs because most editors and language
plugins resolve tools from `PATH` and execute them inside the project. Running
the shim lets mise choose the project tool and load mise env when that tool is
invoked.

Keep the existing interactive shell activation in `~/.zshrc`. The login-profile
shim activation is an IDE compatibility layer, not a replacement for
interactive `mise activate zsh`, direnv ordering, or the spec-007 PATH ordering
rules.

## Acceptance criteria

### `home/dot_zprofile`

- After login-scoped Homebrew PATH setup, guardedly runs
  `eval "$(mise activate zsh --shims)"` when `mise` is available.
- The block lives in `~/.zprofile`, not `~/.zshenv`, because `~/.zshenv` must
  remain pure low-cost env without tool probes or command substitutions.
- The block lives before `~/.zshrc` interactive setup, so login-shell child
  processes launched by IDEs can inherit the mise shim directory even if no
  interactive rc file runs.
- The block documents that shims are for IDE/tool discovery and that arbitrary
  `[env]` entries from mise config are only loaded when a shimmed tool runs.

### `home/dot_zshrc`

- Still runs the existing guarded `mise activate zsh` block for interactive
  shells.
- Does not switch the interactive block to `--shims`; the existing hook-env
  integration is still required for prompt-time project changes and direnv
  ordering.

### Windows PowerShell profile

- Continues to prepend both known native Windows mise shim locations to
  `$env:Path` before `mise activate pwsh`.

### Tests

- Smoke tests assert the zprofile shim block exists, uses `--shims`, and is
  guarded by `command -v mise`.
- Smoke tests assert zshenv does not run `mise activate` or probe for mise.
- Smoke tests assert zshrc still uses the non-shim interactive
  `mise activate zsh` form.
- Windows smoke tests continue asserting the PowerShell profile prepends mise
  shim locations.

## Out of scope

- Installing or configuring IDE plugins such as `mise-vscode`,
  `intellij-mise`, or `mise.el`.
- Editing VS Code, JetBrains, Emacs, Vim, or Neovim user settings directly.
- Creating a `~/.asdf` symlink to the mise data directory for JetBrains/asdf
  compatibility. That can conflict with a real asdf installation and should be
  opt-in.
- Guaranteeing arbitrary mise `[env]` variables are present before an IDE
  invokes a mise shim. Shims load mise env when the shimmed tool runs; deeper
  per-buffer/per-run integration requires IDE-specific plugins or settings.

## Affected files

- `specs/036-mise-ide-integration.md`
- `home/dot_zprofile`
- `tests/test_smoke.sh`
- `tests/windows_smoke.ps1`
