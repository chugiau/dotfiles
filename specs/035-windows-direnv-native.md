# 035 - Use native direnv.exe for Windows PowerShell

## Intent

Opening native PowerShell can fail at the managed profile's
`direnv hook pwsh` line when the active `direnv` command resolves to the
extensionless binary installed by mise/aqua. That command can yield an empty
hook string in PowerShell, and `Invoke-Expression` rejects an empty command.

The official direnv Windows path is a native Windows package/binary on `PATH`
plus the PowerShell hook. Use the WinGet package for native Windows installs
and make the profile prefer `direnv.exe`, not the extensionless mise install
path.

## Acceptance criteria

- Windows package setup installs `direnv.direnv` with WinGet.
- The PowerShell profile looks up `direnv.exe` for the hook.
- The PowerShell profile does not invoke `Invoke-Expression` when the hook
  output is empty or whitespace.
- Windows smoke tests fail if the native direnv package or empty-hook guard is
  removed.

## Out of scope

- Removing `direnv` from the shared mise manifest for POSIX shells.
- Replacing zsh direnv integration.
- Changing per-project `direnv allow` behavior.

## Affected files

- `specs/035-windows-direnv-native.md`
- `home/run_once_before_05-windows-packages.ps1.tmpl`
- `home/dot_config/dotfiles/powershell/profile.ps1`
- `tests/windows_smoke.ps1`
- `tests/test_smoke.sh`
