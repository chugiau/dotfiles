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
  rewrite the comment header)
- `tests/test_smoke.sh` (one new assertion in `[mise activate]`:
  `mise activate zsh` line number exceeds every `export PATH=.*:$PATH`
  line number)
