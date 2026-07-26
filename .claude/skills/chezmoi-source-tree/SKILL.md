---
name: chezmoi-source-tree
description: How the chezmoi source tree under home/ maps to $HOME — source-file naming prefixes (dot_, private_, executable_, encrypted_, empty_, .tmpl), the run_once/run_onchange ordering scheme, the platform ignore split, and the edit-then-apply loop. Load before adding or renaming anything under home/, writing a run script, or when an edit does not seem to reach $HOME.
---

# chezmoi source tree

`.chezmoiroot` points chezmoi at `home/`, so `home/` is the source tree and
`$HOME` is the target. Nothing under `home/` runs from the repo; it runs after
it has been rendered into `$HOME`.

## The edit/apply loop

The mistake to avoid is editing a live file in `$HOME` and losing it on the next
apply, or editing the source and wondering why nothing changed.

1. Edit the source under `home/`.
2. Run `chezmoi apply` (or `dotfiles link`) to materialize it.
3. For anything shell-startup related, open a new shell — the current one still
   has the old definitions sourced.

The runtime/source split matters most for shell modules: `$DOTFILES_REPO` is
`~/.dotfiles` (this repo) and `$DOTFILES` is `~/.config/dotfiles` (what shell
startup actually sources). Source lives at
`home/dot_config/dotfiles/`, with the shell modules in its `modules/`
subdirectory.

## Name prefixes

The filename encodes the target's name and attributes; chezmoi strips the
prefixes when rendering.

- `dot_foo` -> `~/.foo`. Nested: `home/dot_config/mise/config.toml` ->
  `~/.config/mise/config.toml`.
- `private_` -> mode `0600`-ish, used for `private_dot_ssh`, `private_dot_gnupg`.
- `executable_` -> sets the execute bit, e.g.
  `home/dot_claude/executable_statusline-command.sh`.
- `empty_` -> keep a zero-length target instead of removing it.
- `encrypted_` -> age-encrypted at rest; the ciphertext is what gets committed.
- `.tmpl` -> rendered as a Go template at apply time, with chezmoi's `.chezmoi`
  variables available.

`.tmpl` is where per-machine differences belong. Decisions made at apply time —
the `BROWSER` value in `dot_zshenv.tmpl` being `open`, `wslview`, or
`xdg-open` — must not be re-derived per shell invocation.

## Run scripts

`run_once_*` executes once per changed content; `run_onchange_*` re-executes
whenever the rendered script changes. `_before_` runs before the file apply,
`_after_` runs after it. The two-digit number after that is the ordering slot;
read the existing `home/run_*` names before picking one and choose a slot that
lands after everything the script depends on.

Every run script is a `.tmpl`, so it must render before it can run: a syntax
error in the template is an apply-time failure, and a missing shebang produces a
script that runs under the wrong interpreter.

## Platform split

`home/.chezmoiignore` keeps Unix run scripts out of native Windows applies and
Windows PowerShell files out of Unix applies. Any new platform-specific file
needs an entry there, or it will be applied on the wrong OS.

Windows startup has its own runtime split: PowerShell loads
`~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`, which does nothing
but source `$HOME/.config/dotfiles/powershell/profile.ps1`. Windows logic
belongs in `home/dot_config/dotfiles/powershell/`.

## Verifying

`tests/test_smoke.sh` renders templates and asserts against the output, so a
template change is checkable without applying it to a real machine. See the
`dotfiles-test-suite` skill.
