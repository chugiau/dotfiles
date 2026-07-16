# 039 - Default native Windows to the slimfat oh-my-posh theme

## Intent

The native Windows PowerShell profile
(`home/dot_config/dotfiles/powershell/profile.ps1`) only applies a custom
oh-my-posh theme when the user has already dropped a `theme.omp.json` or
`default.omp.json` under `~/.config/oh-my-posh/`. Absent that, it falls back
to `oh-my-posh init pwsh` with no `--config`, which renders oh-my-posh's own
built-in default theme (`jandedobbeleer`).

Ship `slimfat` — one of oh-my-posh's bundled themes — as the out-of-the-box
default on native Windows instead, while still letting a user-dropped
`theme.omp.json` / `default.omp.json` override it.

## Acceptance criteria

- `home/dot_config/dotfiles/powershell/profile.ps1` resolves the oh-my-posh
  config in this order: `~/.config/oh-my-posh/theme.omp.json`, then
  `~/.config/oh-my-posh/default.omp.json`, then — if neither exists and
  `$env:POSH_THEMES_PATH\slimfat.omp.json` exists — the bundled `slimfat`
  theme, then finally no `--config` (oh-my-posh's own built-in default).
- The slimfat lookup is guarded by `Test-Path`; a missing or unset
  `POSH_THEMES_PATH` (broken/partial oh-my-posh install) silently falls
  through to the existing no-`--config` behavior rather than erroring.
- The whole block stays inside the existing `try/catch` that already
  tolerates broken WindowsApps aliases.
- Windows smoke tests fail if the `slimfat` default is removed.

## Out of scope

- Shipping a custom/edited theme JSON file in the repo. `slimfat` is used
  as-is from oh-my-posh's own bundled themes.
- Changing the oh-my-posh theme for WSL2 or POSIX shells — this only
  touches the native Windows PowerShell profile.
- Adding a way to pick a different bundled theme name via config; a user
  who wants something else still drops `theme.omp.json` /
  `default.omp.json` under `~/.config/oh-my-posh/`.

## Affected files

- `specs/039-oh-my-posh-slimfat-theme.md` (new)
- `home/dot_config/dotfiles/powershell/profile.ps1`
- `tests/windows_smoke.ps1`
