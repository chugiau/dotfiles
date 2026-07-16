# 040 - Install Codex CLI on native Windows via the official installer

## Intent

`home/dot_config/mise/config.toml` declares `codex = "latest"`, and mise's
registry lists two backends for that shorthand: `aqua:openai/codex` and
`npm:@openai/codex`. Spec 011 assumed the aqua backend — a static release
binary, no Node toolchain — would always win, the same way bare `eza =
"latest"` was assumed to pull the aqua backend until spec 034 found it
actually resolved to `cargo:eza` on native Windows and had to be pinned
explicitly. An unpinned shorthand can silently pick a different backend
across mise versions/platforms, so Codex should not keep depending on that
assumption on native Windows: stop relying on mise's bare-shorthand
resolution there and install Codex CLI directly instead, while leaving the
already-working POSIX/mise path (spec 011) untouched.

Native Windows installs Codex CLI with OpenAI's official one-liner:

```
powershell -ExecutionPolicy ByPass -Command "irm https://chatgpt.com/codex/install.ps1 | iex"
```

`install.ps1` downloads the `codex.exe` release asset for the current
architecture and wires `%USERPROFILE%\.codex\...` onto the user `PATH` — no
Node, no npm, no mise backend ambiguity, and no package manager of any kind
in between. Note the companion `install.sh` explicitly refuses to run
outside macOS/Linux ("install.sh supports macOS and Linux. Use install.ps1
on Windows."), so the plain `curl -fsSL .../install.sh | sh` form is
POSIX-only; native Windows needs the `.ps1` counterpart, run through a
nested `powershell -ExecutionPolicy ByPass` invocation so it works
regardless of the interpreter/policy the calling script itself runs under.

## Acceptance criteria

### `home/dot_config/mise/config.toml`

- `codex` is declared as `{ version = "latest", os = ["linux", "macos"] }`
  instead of the bare `codex = "latest"` shorthand, so `mise install` /
  `mise upgrade` skip it entirely on native Windows.
- POSIX hosts are unaffected: mise still installs `codex` there through its
  existing resolution (spec 011).

### `home/run_once_after_12-codex-windows.ps1.tmpl` (new)

- Windows-only (early-returns when `$IsWindows` is false, matching
  `run_once_before_05-windows-packages.ps1.tmpl` /
  `run_onchange_after_11-mise-windows.ps1.tmpl`).
- No-ops when `codex` is already resolvable on `PATH`.
- Otherwise runs the official one-liner: `powershell -ExecutionPolicy
  ByPass -Command 'irm https://chatgpt.com/codex/install.ps1 | iex'`. No
  npm, no mise, no other package/management tool.
- A failed install (thrown error or non-zero exit code) is caught and
  surfaced as a warning, not a fatal error, matching the rest of the
  Windows package/mise run scripts.

### `home/.chezmoiignore`

- Non-Windows hosts ignore `12-codex-windows.ps1` by target script name,
  matching the existing `05-windows-packages.ps1` / `11-mise-windows.ps1`
  entries.

### `bin/dotfiles.ps1`

- `Invoke-Update` re-runs the same one-liner when `codex` is present, so
  `dotfiles.ps1 update` keeps native Windows Codex current the same way
  `mise upgrade` keeps POSIX Codex current.

### `tests/windows_smoke.ps1` / `tests/test_smoke.sh`

- Windows smoke asserts the new run script exists, parses, is Windows-only,
  runs the literal `irm https://chatgpt.com/codex/install.ps1 | iex`
  one-liner under `ExecutionPolicy ByPass`, contains no `npm` reference, is
  referenced from `Invoke-Update`, and that `.chezmoiignore` ignores it on
  non-Windows.
- Windows smoke asserts the mise manifest excludes `codex` from Windows via
  an `os =` filter.
- POSIX smoke's existing "mise config declares codex under [tools]"
  assertion continues to pass unchanged against the new inline-table form.

### `README.md`

- The inline `[tools]` example and the "What Gets Installed" table note
  that native Windows installs Codex CLI outside of mise, via the official
  installer.

## Out of scope

- Changing how POSIX/WSL2 hosts install Codex (spec 011 stands there).
- Pinning a specific Codex version on Windows — `install.ps1` defaults to
  `latest`, matching the POSIX `"latest"` pin.
- Adding Codex to the `bin/dotfiles doctor` (POSIX) loop — unchanged from
  spec 011's leaf-tool rationale. `bin/dotfiles.ps1 doctor` already checks
  for `codex` on `PATH` regardless of install method, so it needs no edit.
- Authenticating Codex CLI — same out-of-scope note as spec 011.

## Affected files

- `specs/040-codex-windows-install.md` (new)
- `home/dot_config/mise/config.toml`
- `home/run_once_after_12-codex-windows.ps1.tmpl` (new)
- `home/.chezmoiignore`
- `bin/dotfiles.ps1`
- `tests/windows_smoke.ps1`
- `tests/test_smoke.sh`
- `README.md`
