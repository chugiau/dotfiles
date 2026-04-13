# 007 — `mise activate` must run last in `dot_zshrc`

## Intent

Fresh `mise doctor` run on a WSL box surfaces:

```
1 warning found:

1. mise tool paths are not first in PATH. These paths take precedence:
     ~/.bun/bin
     ~/.dotnet
     ~/.dotnet/tools
     ~/.local/share/pnpm
   This may cause system-installed tools to be used instead of mise-managed versions.
   Ensure `mise activate` runs after other PATH modifications in your shell rc file.
```

The diagnosis is mechanical. `home/dot_zshrc` currently `eval`s
`mise activate zsh` near the top of the file (right after the p10k
instant-prompt block), and four separate stanzas below it prepend to
`$PATH`:

| Stanza | Line (pre-fix) | Prepends                                        |
|--------|----------------|-------------------------------------------------|
| fnm    | ~91            | `$HOME/.local/share/fnm`                        |
| pnpm   | ~108           | `$HOME/.local/share/pnpm`                       |
| dotnet | ~125           | `$HOME/.dotnet:$HOME/.dotnet/tools`             |
| bun    | ~148           | `$HOME/.bun/bin`                                |

Each prepend pushes the mise shim dir further down `$PATH`, so a mise-
managed `node`, `npm`, `npx`, `bun`, or `pnpm` (all of which spec 002,
003, and 006 deliberately route through mise) gets shadowed by whatever
standalone copy happens to live under `~/.bun`, `~/.dotnet`, or
`~/.local/share/pnpm`. That is exactly the regression mise's warning is
meant to surface, and it defeats the point of pinning `node = "lts"` in
spec 006.

mise's own advice is quoted verbatim in the warning: **"Ensure
`mise activate` runs after other PATH modifications in your shell rc
file."** The fix is purely ordering — no stanza is removed, no guard is
loosened, nothing downstream changes. `mise activate zsh` moves to the
bottom of `dot_zshrc`, below every existing `export PATH=…:$PATH`
prepend, and the inline comment above it is rewritten to record *why*
the block sits there so a future reader does not innocently hoist it
back up.

Moving the activate block past p10k's instant-prompt marker is safe:
that marker only gates code which may need console input (passphrase
prompts, `[y/n]` confirmations), and `mise activate` is silent. Moving
it past `source $ZSH/oh-my-zsh.sh` is also safe — none of the enabled
oh-my-zsh plugins (`git`, `fnm`, `aws`) need a mise-managed tool during
sourcing, and mise's precmd hook is just appended to
`precmd_functions`, not installed as a singleton.

## Acceptance criteria

### `home/dot_zshrc`

- The `if command -v mise >/dev/null 2>&1; then eval "$(mise activate zsh)"; fi`
  block sits **below** every stanza that prepends to `$PATH` — fnm,
  pnpm, dotnet, and bun. A top-down walk of the file finds the last
  `export PATH=…:$PATH` line *before* the `mise activate zsh` line, not
  after it.
- The comment header above the mise-activate block is rewritten. Old
  wording ("Runs after `~/.local/bin` is on PATH so the mise entrypoint
  is reachable") is replaced with an explanation that the block runs
  **last** so the mise shim dir ends up first in `$PATH`, ahead of
  `~/.bun`, `~/.dotnet`, and `~/.local/share/pnpm`. The comment
  explicitly names `mise doctor`'s "tool paths are not first in PATH"
  warning so a future reader grepping for that string lands on the
  explanation.
- The existing `command -v mise` guard (spec smoke-tested at
  `tests/test_smoke.sh:285-293`) survives unchanged — the block moves,
  it does not get rewritten.
- No other stanza is touched. In particular the bun / dotnet / pnpm
  guards introduced by spec 003 stay exactly as they are; this spec is
  strictly about *order*, not presence.

### `tests/test_smoke.sh`

- The `[mise activate]` section grows one new assertion that walks
  `home/dot_zshrc` top-down, records the line number of the last
  `export PATH=.*:$PATH` prepend and the line number of `mise activate
  zsh`, and fails if the last prepend comes *after* the activate line.
  The assertion is phrased against the prepend pattern (not specific
  tool names) so adding a new PATH-prepending stanza in the future
  regresses the test unless that stanza is itself placed above the
  activate block.

## Out of scope

- **Removing fnm.** With spec 006 pinning `node = "lts"` through mise,
  fnm is redundant for the common `node`/`npm`/`npx` case, and the
  cleanest long-term fix is to delete the fnm stanza outright. That is
  a separate decision (per-project `.nvmrc` workflows still want fnm)
  and belongs in its own spec.
- **Removing the bun / dotnet / pnpm stanzas.** Each is already guarded
  on the binary existing (spec 003), so a machine that has never used
  bun, dotnet, or a global pnpm package still has clean PATH ordering.
  When the guards do fire, the user is intentionally opting into a
  standalone install, and the ordering fix here ensures mise still
  wins.
- **Touching `dot_zprofile` or `dot_zshenv`.** All PATH writes in those
  files (`brew shellenv`, `$HOME/bin`, `$HOME/.local/bin`,
  `$DOTFILES_REPO/shellscripts`) run *before* `dot_zshrc`, so
  `mise activate` is already ordered after them. Moving mise-activate
  to the bottom of `dot_zshrc` only has to beat the stanzas inside
  `dot_zshrc` itself.
- **Changing `bin/dotfiles doctor` or the mise-doctor wireup.** The
  doctor loop already surfaces `mise doctor`'s output (spec 006), which
  is how this warning became visible in the first place. No change
  needed there — the warning goes away once the ordering is fixed.
- **Per-tool `mise activate --shims` vs `mise activate zsh` mode.**
  This spec does not re-litigate the shims-vs-hook-env choice; it only
  fixes the ordering of the existing `eval "$(mise activate zsh)"`
  call.

## Affected files

- `specs/007-mise-activate-last.md` (new)
- `home/dot_zshrc` (move the `mise activate zsh` block to the bottom,
  rewrite the comment header; switch the bun, dotnet, and pnpm blocks
  from prepend to append per the amendment below)
- `tests/test_smoke.sh` (one new assertion in `[mise activate]`:
  `mise activate zsh` line number exceeds every `export PATH=.*:$PATH`
  line number; three new assertions in `[dot_zshrc guards]` that the
  bun, dotnet, and pnpm blocks append rather than prepend)

## Amendment — append is mandatory, ordering alone is not enough

After landing the ordering fix above, `zsh -i -c 'mise doctor'` still
reported three paths in front of mise tools:

```
1. mise tool paths are not first in PATH. These paths take precedence:
     ~/.bun/bin
     ~/.dotnet
     ~/.dotnet/tools
```

`~/.local/share/pnpm` dropped off the list (because on this box
`PNPM_HOME` was empty, so spec 003's `[ -d "$PNPM_HOME" ]` guard short-
circuited the prepend), but bun and dotnet stayed ahead.

**Root cause.** `mise activate zsh` runs in *hook-env* mode, not
*shims* mode. Its output is not a simple `PATH=$mise_shims:$PATH`
prepend. Instead it:

1. Captures `PATH` at `eval` time into `__MISE_ORIG_PATH`.
2. Installs a zsh `precmd` hook that calls `mise hook-env`.
3. On every prompt, `mise hook-env` rebuilds `PATH` by splicing mise
   tool paths into a *specific slot* computed from a diff against the
   stored original — not unconditionally at the front.

Empirically, whether the bun/dotnet stanzas prepend *before* or
*after* `mise activate`, the splice lands mise tools **after** those
stanzas. That is:

```
# zshrc with mise activate LAST (as spec 007 originally prescribed):
[bun, dotnet, dotnet/tools, mise-bat, mise-eza, …, $HOME/bin, …]
#                           ^^^^^^^^^^^^^^^^^^
#                           mise spliced here, not at the front

# zshrc with mise activate FIRST (pre-spec-007 ordering):
[bun, dotnet, dotnet/tools, mise-bat, mise-eza, …, $HOME/bin, …]
#                           (same splice point)
```

The ordering of the `mise activate` call does not change the final
splice position — only the *presence* of prepended entries ahead of
mise at `eval` time does. So moving `mise activate` to the bottom of
`dot_zshrc` does not, on its own, eliminate the warning.

**Real fix.** Stop prepending. The bun, dotnet, and pnpm stanzas all
exist as *fallbacks* for a standalone install alongside the mise-
managed copy (see spec 003 for bun, spec 002 for pnpm). They should
append to `PATH`, not prepend:

```sh
# was: export PATH="$BUN_INSTALL/bin:$PATH"
      export PATH="$PATH:$BUN_INSTALL/bin"
# was: export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"
      export PATH="$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools"
# was: *) export PATH="$PNPM_HOME:$PATH" ;;
      *) export PATH="$PATH:$PNPM_HOME" ;;
```

The semantics this buys:

- **bun** — `mise` declares `bun = "latest"` in `mise/config.toml`, so
  mise's bun is the intended primary. A leftover `~/.bun/bin/bun`
  still loads as a fallback if mise's shim is missing, which is the
  only case the guard was ever meant to cover.
- **pnpm** — mise declares `pnpm = "latest"` too, and `$PNPM_HOME`
  (`~/.local/share/pnpm`) is the install directory for *global pnpm
  packages* (`pnpm add -g …`), not the pnpm binary itself. Packages
  installed there still need to be callable; appending keeps them
  callable without overtaking mise's pnpm.
- **dotnet** — `~/.dotnet` is not mise-managed. Appending does not
  lose anything, because there is effectively no other `dotnet` on
  PATH to fight with; the block still makes `dotnet` and `dotnet
  tool` invocations work.

The `mise activate` block still moves to the bottom of `dot_zshrc`
(the original spec-007 change) as defense-in-depth, but the
controlling fix is the prepend→append switch.

### Additional acceptance criteria

- `home/dot_zshrc` bun block writes `export PATH="$PATH:$BUN_INSTALL/bin"`.
- `home/dot_zshrc` dotnet block writes
  `export PATH="$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools"`.
- `home/dot_zshrc` pnpm `case` arm writes
  `export PATH="$PATH:$PNPM_HOME"`.
- `tests/test_smoke.sh` `[dot_zshrc guards]` section asserts each of
  the three blocks appends (pattern: `"\$PATH:…"`) rather than
  prepends (pattern: `"…:\$PATH"`).
- Running `zsh -i -c 'mise doctor'` on a fresh shell reports **no
  warnings** (verified by hand — not automated because it depends on
  which standalone installs the host has).
