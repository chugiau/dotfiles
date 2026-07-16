# 042 - Windows direnv needs $env:HOME

## Intent

Native Windows PowerShell prints `direnv: error couldn't find a
configuration directory for direnv` on every `cd`, including into
directories with no `.envrc`/`.env` at all.

Root cause: direnv (a Go binary) resolves its own config directory by
checking `XDG_CONFIG_HOME`, then falling back to the `HOME` *environment
variable* (`env["HOME"]`), joining `.config/direnv`. It does not consult
`USERPROFILE` or PowerShell's automatic `$HOME` variable. PowerShell 7+
always populates the automatic `$HOME` variable, but it does not export a
matching `HOME` entry into the process environment block on Windows. Since
`home/dot_config/dotfiles/powershell/profile.ps1` never sets `$env:HOME`,
every `direnv export pwsh` invocation from the location-changed hook (spec
035) fails that lookup and direnv prints the config-directory error instead
of silently no-op'ing for directories with nothing to load.

The fix is to export `$env:HOME = $HOME` early in the shared profile, before
`direnv.exe hook pwsh` is wired up, so direnv's XDG lookup succeeds the same
way it does on POSIX shells where `$HOME` is already a real environment
variable.

## Acceptance criteria

- `home/dot_config/dotfiles/powershell/profile.ps1` sets `$env:HOME` from
  the automatic `$HOME` variable before the direnv hook block.
- The assignment happens unconditionally (not gated on direnv being
  installed), since other POSIX-ported tools can have the same
  `HOME`-vs-`USERPROFILE` expectation mismatch.
- Windows smoke tests fail if the `$env:HOME` assignment is missing or is
  placed after the direnv hook block.

## Out of scope

- Setting `HOME` as a persistent machine/user-level Windows environment
  variable (e.g. via `setx` or winget package config). Scope is limited to
  the interactive PowerShell profile, which is where the direnv hook (spec
  035) actually runs.
- Changing direnv's own config resolution behavior (upstream project).
- Touching `home/dot_config/direnv/direnv.toml` or `.envrc`/`.env` handling.
- POSIX shells (zsh) — `$HOME` is already a real environment variable there.

## Affected files

- `specs/042-windows-direnv-home-env.md`
- `home/dot_config/dotfiles/powershell/profile.ps1`
- `tests/windows_smoke.ps1`
