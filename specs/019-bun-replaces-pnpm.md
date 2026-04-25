# 019 — bun replaces pnpm as the JS package manager

## Intent

Spec 002 added `pnpm` to mise so a fresh machine had `pnpm` and `pnpx` on
`PATH` for npm-distributed CLIs.  Spec 003 then added `bun` alongside it.
With `bun` in place, `pnpm` is redundant for this dotfile's use case:
`bun install`, `bun add`, `bun run`, and `bunx` cover everything `pnpm`
and `pnpx` were used for here, with a single binary instead of two and
no global-install dance under `~/.local/share/pnpm`.

This spec retires `pnpm` from the toolchain.  `bun` is now the sole
JS-side package manager managed by these dotfiles.  This supersedes
spec 002 — the old spec stays in `specs/` as a historical record but
no longer reflects current behaviour.

## Acceptance criteria

- `home/dot_config/mise/config.toml` no longer lists `pnpm` under
  `[tools]`.  `bun` and `node` remain declared as before.
- `home/dot_zshrc` no longer contains a `command -v pnpm` block,
  `PNPM_HOME` export, `~/.local/share/pnpm` PATH manipulation, or
  `_pnpm` completion generation.  Zero `PNPM_HOME` references in the
  file.
- `home/dot_config/dotfiles/modules/pkg-quarantine.zsh` no longer
  defines a `pnpm()` wrapper function.  The header comment lists only
  `npm, yarn, bun` for the JS side.  The `bun()`, `npm()`, `yarn()`
  wrappers are unchanged.
- `README.md` does not list `pnpm` in the mise tool table or the inline
  `[tools]` block.  `bun` continues to appear in both.
- `tests/test_smoke.sh` is updated:
  - The positive assertion that `mise/config.toml` declares `pnpm` is
    inverted into a negative assertion (mirroring the spec-005 pattern
    used for `neovim`): the test now fails if `pnpm` is declared.
  - The four `dot_zshrc` PNPM assertions (`export PNPM_HOME=` count,
    `[ -d "$PNPM_HOME" ]` guard, append-not-prepend pair) are replaced
    with a single negative assertion: zero `PNPM_HOME` matches in
    `dot_zshrc`.
- `sh tests/test_smoke.sh` passes from the repo root.

## Out of scope

- Migrating existing `pnpm` lockfiles or projects.  This dotfile change
  removes the binary from the managed toolchain; downstream projects
  that need `pnpm` install it themselves.
- Adding a `pnpx`/`pnpm` shell alias to `bunx`/`bun`.  If a third-party
  recipe insists on `pnpm`, the user can `mise use -g pnpm@latest` ad
  hoc, or install it project-locally.
- Touching specs 003 / 006 / 007 / 008 / 011 / 015 that reference pnpm
  in passing as historical context — they remain accurate as records of
  the state at the time they were written.
- Rewriting spec 002.  Per the SDD rule, a superseded spec stays put
  as history; the new spec documents the change.

## Affected files

- `specs/019-bun-replaces-pnpm.md` (new)
- `home/dot_config/mise/config.toml` (drop `pnpm` line)
- `home/dot_zshrc` (drop the `command -v pnpm` block, ~24 lines)
- `home/dot_config/dotfiles/modules/pkg-quarantine.zsh` (drop `pnpm()`,
  update header comment)
- `README.md` (drop `pnpm` from the dev-tools row and the inline TOML
  example)
- `tests/test_smoke.sh` (invert pnpm-mise assertion, replace four
  PNPM_HOME assertions with one negative assertion)
