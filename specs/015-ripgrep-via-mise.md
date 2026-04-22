# 015 — Install ripgrep via mise

## Intent

[ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) is the recursive
regex search tool this shell — and Claude Code's `Grep` tool — reach for
dozens of times per session. Today `rg` is whatever the distro ships
(Ubuntu noble is still on 14.1.0-1), which drifts behind upstream and
varies per machine. Declaring it under mise fixes both: every box runs
the same `latest` that `dotfiles update` refreshes on a cadence we
control, exactly like `bat`, `eza`, and the rest of the manifest.

`ripgrep` is first-class in mise's registry:

```
$ mise registry | grep '^ripgrep'
ripgrep    aqua:BurntSushi/ripgrep    asdf:...    cargo:ripgrep
```

The aqua backend pulls the static release binary from upstream GitHub,
so adding `ripgrep = "latest"` to `home/dot_config/mise/config.toml`
drops it straight into `~/.local/share/mise/shims/` on the next
`dotfiles install`. Spec 007 guarantees the shim dir sits before
`/usr/bin`, so the mise `rg` shadows any apt / pacman / dnf copy
without us having to uninstall the distro package.

This spec follows the leaf-tool precedent of spec 002 (pnpm) / 003
(bun) / 008 (gh + glab) / 011 (codex): `ripgrep` is **not** added to
the `bin/dotfiles doctor` loop — a missing `rg` surfaces as
"command not found", not as a cryptic LSP or hook failure, so doctor
gains nothing from pre-flighting it.

The canonical registry name is `ripgrep` (the `rg` entry in
`mise registry` is an alias). The config uses `ripgrep` to stay
self-documenting, matching how the manifest already prefers full tool
names (`lazygit`, not `lg`).

## Acceptance criteria

### `home/dot_config/mise/config.toml`

- Declares `ripgrep = "latest"` under `[tools]`, pinned to `latest` to
  match the surrounding entries.
- The new line sits with the file-viewer / terminal-utility cluster
  (`bat`, `eza`, `lazygit`, `glow`), since `rg` is the same shape of
  tool — a Rust-written replacement for a classic Unix utility that
  you reach for interactively. Placing it after `glow` keeps the
  manifest grouped: file viewers → JS toolchain → forge CLIs →
  coding agents → shell utilities.

### `tests/test_smoke.sh`

- Asserts that `mise/config.toml` declares `ripgrep` under `[tools]`,
  mirroring the existing `codex` / `gh` / `glab` / `bun` assertions so
  a regression (someone deleting the line) is caught by the smoke
  suite.

### `README.md`

- The "What Gets Installed" table row for **Dev tools** lists
  `ripgrep` alongside the existing mise-managed entries.
- The inline `[tools]` example block under "Tool management via mise"
  shows the `ripgrep = "latest"` line, in the same position as the
  manifest.

## Out of scope

- Adding `ripgrep` to the `bin/dotfiles doctor` loop — see the intent
  section for why (leaf-tool rationale, matches spec 002 / 003 / 008 /
  011).
- Uninstalling the distro `ripgrep` package. Spec 007's PATH ordering
  already makes the mise shim win; a leftover apt copy is harmless and
  removing it is per-machine cleanup, not a dotfiles concern.
- Adding `rg` as an alias or wrapper. The mise shim is already named
  `rg`, nothing to wire up.
- Shell completion wireups. oh-my-zsh already picks up completion
  from the mise shim PATH; nothing explicit to add here.
- Installing related tools (`ripgrep-all`, `ugrep`, `ast-grep`). Only
  `ripgrep` itself.
- Touching `CLAUDE.md` / `AGENTS.md` — this is an additive leaf-tool
  change with no new repo convention to record.

## Affected files

- `specs/015-ripgrep-via-mise.md` (new)
- `home/dot_config/mise/config.toml` (add `ripgrep` line)
- `tests/test_smoke.sh` (one new assertion: ripgrep in mise config)
- `README.md` (Dev tools row + inline `[tools]` example)
