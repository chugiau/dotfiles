# 009 — Per-platform `$BROWSER` + wslu on WSL Debian

## Intent

`home/dot_zshenv:16` hard-codes `export BROWSER="brave.exe"`. That only
makes sense on a WSL2 box that happens to have Brave installed on the
Windows host — on macOS and native Linux it resolves to a non-existent
command, on WSL boxes without Brave it does the same, and it couples
the dotfiles to one specific Windows browser rather than the
Windows-side user default.

Fix it by dispatching `BROWSER` at `chezmoi apply` time on
`(.chezmoi.os, .chezmoi.kernel.osrelease)`:

- **WSL2** (`linux` + kernel osrelease contains `microsoft`) →
  `wslview`. Ships with the `wslu` package and forwards URLs to the
  Windows host's *default* browser (whatever the user set it to),
  which is the right abstraction.
- **macOS** → `open`. System builtin, dispatches URLs via
  LaunchServices so the Mac-side user default applies.
- **native Linux** → `xdg-open`. Freedesktop standard, present with
  every desktop environment.
- **anything else** (unknown `chezmoi.os`) → leave `BROWSER` unset.
  Tools then fall back to their own internal defaults
  (`sensible-browser`, `www-browser`, …); writing a value that doesn't
  resolve is strictly worse.

Two reasons for resolving this at `chezmoi apply` time (via a template)
rather than at shell startup time (via runtime detection):

1. `.zshenv` runs on *every* zsh invocation — login, non-login,
   interactive, non-interactive, scripts, `ssh host 'cmd'`. Per-shell
   runtime cost matters.
2. `AGENTS.md` explicitly forbids `command -v` probes and side effects
   in `.zshenv` — "pure env exports only". A template evaluated at apply
   time keeps the file a flat list of exports, which is what the rule
   requires.

Separately: spec 009 guarantees `wslview` is actually installed on a
Debian/Ubuntu WSL box. Today the binary is only present on this
machine because Ubuntu happens to ship `wslu` by default — the dotfiles'
`install_debian()` does not list it. Add a `/proc/version`-guarded
`apt-get install wslu` so the `BROWSER=wslview` export is backed by a
real executable on every fresh WSL bootstrap.

## Acceptance criteria

### `home/dot_zshenv` → `home/dot_zshenv.tmpl`

- The plain-file `home/dot_zshenv` is gone; `home/dot_zshenv.tmpl`
  exists in its place.
- Every non-BROWSER export from the previous file is preserved
  byte-for-byte in the template source: `DOTFILES_REPO`, `DOTFILES`,
  `EDITOR`, `VISUAL`, `DOTNET_CLI_TELEMETRY_OPTOUT`, the
  `$HOME/bin:$HOME/.local/bin` `$PATH` prepend, and the
  `$DOTFILES_REPO/shellscripts` `$PATH` prepend.
- The hard-coded `BROWSER="brave.exe"` literal is absent.
- The template contains all three literal dispatch outputs —
  `BROWSER="wslview"`, `BROWSER="open"`, `BROWSER="xdg-open"` — inside
  a Go-template branch that dispatches on
  `(.chezmoi.os, .chezmoi.kernel.osrelease)`.
- The WSL branch is guarded by a `contains "microsoft" (lower
  .chezmoi.kernel.osrelease)` check so any kernel osrelease casing
  matches (Ubuntu and Debian render it lowercase; Arch WSL renders it
  with a capital `M` on some kernels).
- Rendered via `chezmoi execute-template` on *this* box (which is
  WSL2), the output parses under `sh -n`, contains exactly one
  `BROWSER=` line, and that line is `export BROWSER="wslview"`.

### `home/run_once_before_10-system-packages.sh.tmpl`

- `install_debian()` installs `wslu` **only** when running on WSL,
  detected via `grep -qi microsoft /proc/version`. Non-WSL Debian
  boxes skip the package entirely.
- The WSL-guarded `apt-get install` is a separate step from the
  main package-list install so a `wslu` package-manager failure does
  not fail the core install. (`|| true` tail is acceptable — wslu is
  a convenience, not a hard dependency for the rest of the dotfiles.)
- The script is still idempotent (`apt-get install` is a no-op when
  `wslu` is already present) and still POSIX-sh clean.
- The detection is runtime shell (`grep /proc/version`), not a Go
  template branch. This keeps the template rendering identical on
  every Debian host — the WSL/non-WSL split happens once, at
  run-time, inside the rendered script.

### `tests/test_smoke.sh`

- The `[home/ source tree]` `check_exists "home/dot_zshenv"` line is
  retargeted to `home/dot_zshenv.tmpl`.
- The `[dot_zshenv]` block (spec 004 assertions) is retargeted to
  `home/dot_zshenv.tmpl` and still asserts presence of
  `DOTFILES_REPO=`, `DOTFILES=`, `EDITOR=`, `VISUAL=`, `BROWSER=`,
  `DOTNET_CLI_TELEMETRY_OPTOUT=`.
- A new `[spec 009 — browser per platform]` block asserts:
  1. `home/dot_zshenv` (plain) no longer exists.
  2. `home/dot_zshenv.tmpl` contains all three literal dispatch
     outputs: `BROWSER="wslview"`, `BROWSER="open"`,
     `BROWSER="xdg-open"`.
  3. The hard-coded `BROWSER="brave.exe"` literal is gone.
  4. The WSL branch uses `contains "microsoft" (lower
     .chezmoi.kernel.osrelease)`.
  5. When `chezmoi` is available, render the template and assert the
     output parses under `sh -n` and contains exactly one `BROWSER=`
     line. (On this box the line is `wslview`; the assertion is
     tolerant of the *value* but strict on "exactly one".)
- A new `[spec 009 — wslu on Debian WSL]` block asserts that
  `run_once_before_10-system-packages.sh.tmpl`:
  1. References the `wslu` package name.
  2. Guards the install on `grep -qi microsoft /proc/version`.

## Out of scope

- Picking an alternate Linux fallback (`sensible-browser`,
  `www-browser`, …). Spec is pinned to `xdg-open` per design review.
- Runtime shell detection of WSL inside `.zshenv`. Rejected because
  `.zshenv` is pure-exports per `AGENTS.md`.
- Generalising the approach to `$PAGER`, `$MANPAGER`, etc. Those are
  not broken today.
- Migrating `dot_zprofile`'s fcitx5 block to use the same template
  dispatch pattern. Spec 004 handled that separately with a runtime
  `command -v` guard, which is correct because `dot_zprofile` is
  login-scoped and may have side effects.
- Adding `wslu` on Arch/Fedora WSL installs. `install_arch` and
  `install_fedora` do not gain a `wslu` line in this spec — those
  distros install `wslu` from the AUR / COPR respectively, which is
  a meaningfully larger change.
- Extending `bin/dotfiles doctor` to probe `$BROWSER`. Doctor already
  covers the tools; BROWSER is an env var, not a managed binary.

## Affected files

- `specs/009-browser-per-platform.md` (new)
- `home/dot_zshenv` → `home/dot_zshenv.tmpl` (rename + template
  dispatch on `BROWSER`)
- `home/run_once_before_10-system-packages.sh.tmpl` (WSL-guarded
  `wslu` install in `install_debian`)
- `tests/test_smoke.sh` (retarget existing `_zshenv` checks to the
  `.tmpl`, add spec 009 assertions)
