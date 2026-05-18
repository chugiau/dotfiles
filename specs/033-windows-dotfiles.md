# 033 - Windows dotfiles support

## Intent

Make this dotfiles repository usable as a first-class Windows checkout while
keeping the existing macOS, Linux, and WSL2 paths intact. Windows should use the
same chezmoi source tree and the same mise manifest, but it needs native
PowerShell entrypoints because the POSIX bootstrap and zsh runtime scripts are
not appropriate on a Windows host.

## Acceptance criteria

- A fresh Windows machine has a documented native bootstrap entrypoint:
  `bootstrap.ps1`.
- Windows users can run a native wrapper, `bin/dotfiles.ps1`, with the same
  core verbs as the POSIX wrapper: `install`, `update`, `link`, `check`,
  `doctor`, `test`, `secrets-init`, and `edit`.
- Chezmoi deploys a guarded PowerShell profile that does not fail when optional
  tools such as oh-my-posh, mise, direnv, or completion files are missing.
- Windows package setup uses winget only for system prerequisites and native
  helpers; the shared dev toolchain still comes from mise.
- Windows `chezmoi apply` runs PowerShell-native package and mise install
  scripts instead of Unix shell/bootstrap scripts.
- Non-Windows `chezmoi apply` ignores Windows-only PowerShell profile and run
  scripts.
- `home/.chezmoiignore` uses chezmoi target paths, not source attribute names:
  run scripts are ignored by their generated script names such as
  `05-windows-packages.ps1`, and configured directories use target paths such
  as `.config/dotfiles/powershell/`.
- Tests include a PowerShell smoke suite that parses Windows scripts and checks
  the expected structure without requiring winget, chezmoi, mise, or network
  access.
- README documents Windows setup and the supported platform status.

## Out of scope

- Replacing the existing zsh/oh-my-zsh/powerlevel10k workflow on Unix-like
  platforms.
- Managing Windows Terminal settings, fonts, SSH keys, GPG keys, or personal
  secrets.
- Installing Neovim system-wide on Windows outside the shared mise toolchain.
- Making POSIX `bin/dotfiles` itself run under native PowerShell.

## Affected files

- `bootstrap.ps1`
- `bin/dotfiles.ps1`
- `home/.chezmoiignore`
- `home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`
- `home/dot_config/dotfiles/powershell/profile.ps1`
- `home/run_once_before_05-windows-packages.ps1.tmpl`
- `home/run_onchange_after_11-mise-windows.ps1.tmpl`
- `tests/windows_smoke.ps1`
- `tests/test_smoke.sh`
- `README.md`
- `AGENTS.md`
