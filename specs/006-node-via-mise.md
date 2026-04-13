# 006 — Install Node.js LTS via mise

## Intent

`home/dot_config/mise/config.toml` already manages the JavaScript-adjacent
toolchain — `pnpm` (spec 002) and `bun` (spec 003) — but no actual
Node.js runtime. That works for a narrow slice of use cases (pnpm and bun
are standalone binaries), but it leaves a gap whenever a tool, script,
LSP server, or Claude Code hook reaches for `node`, `npm`, or `npx`
directly:

- Most language servers shipped via `npm` (typescript-language-server,
  vscode-langservers-extracted, …) need a `node` binary on `PATH`.
- A meaningful number of CLI utilities still ship as `npm` packages and
  expect `npx` to bootstrap them.
- pnpm itself can run pure-JS package scripts under its bundled runtime
  fallback, but anything that calls `process.versions.node` or spawns
  `node` directly breaks without a real runtime present.

mise ships a first-class `node` plugin. Pinning it to the **`lts`**
alias gives us:

- The current LTS major track (resolved by mise at install time, today
  Node 22 "Jod"), so `dotfiles update` → `mise upgrade` rides every LTS
  point release without a manifest edit.
- An automatic move to the next LTS major when it lands, no human
  intervention needed beyond the regular update cadence.
- `node`, `npm`, and `npx` shimmed into `~/.local/share/mise/shims/`
  alongside every other mise tool, so the same `mise activate zsh` line
  in `dot_zshrc` makes them visible.

The other mise entries pin `latest`, but `node` is the one tool here
where the LTS alias is meaningfully different from `latest` — current
Node releases ship breaking changes between majors and LTS is the
documented production track. Pinning `lts` is a deliberate divergence
from the rest of the manifest, not an oversight.

This spec also explicitly *opts into* updating the `bin/dotfiles doctor`
loop, unlike spec 002 (which kept the doctor loop out of scope for
`pnpm`). The reasoning is asymmetric: `pnpm`/`bun` are leaf tools whose
absence is obvious the moment you try to use them, whereas a missing
`node` typically surfaces as a cryptic LSP / hook failure deep inside
another tool. Surfacing it via `dotfiles doctor` short-circuits that
debugging loop.

## Acceptance criteria

### `home/dot_config/mise/config.toml`

- Declares `node = "lts"` under `[tools]`. Pin uses the `lts` alias, not
  `latest` and not a numeric major, so the manifest tracks the LTS line
  without future edits.
- The new line sits with the other JS-toolchain entries (`pnpm`, `bun`)
  rather than alphabetically interleaved with the file viewers, so the
  grouping in the file mirrors the README's documentation.

### `bin/dotfiles`

- The `for cmd in …` loop inside `cmd_doctor` (currently
  `bin/dotfiles:164`) includes `node`, slotted in with the other
  mise-shimmed tools (`bat eza lazygit glow`) rather than at the end —
  this keeps system tools, mise tools, and dotfiles tools visually
  grouped, matching the existing pattern.

### `tests/test_smoke.sh`

- Asserts that `home/dot_config/mise/config.toml` declares `node` under
  `[tools]`, mirroring the existing `pnpm` and `bun` assertions so a
  regression (someone deleting the line) is caught by the smoke suite.
- Asserts that the `bin/dotfiles` doctor loop contains `node` as a
  word inside a `for cmd in …` line, so removing it from the loop
  regresses the suite too.

### `README.md`

- The "What Gets Installed" table row for **Dev tools** lists `node`
  alongside `bat, eza, lazygit, glow, pnpm, bun`.
- The inline `[tools]` example block under "Tool management via mise"
  shows the `node = "lts"` line, in the same position as the manifest.

## Out of scope

- Pinning a specific Node major or minor version. `lts` is the contract;
  bumping past it is a follow-up spec if and when we need to.
- Installing `corepack`, `yarn`, or any other JS package manager. mise's
  node plugin already ships `npm` and `npx`, and `pnpm`/`bun` are
  separately managed.
- Per-project Node version pinning via `.mise.toml`. That is a
  per-repository concern, not a dotfiles concern.
- Wiring `node` into `mise doctor` failure modes beyond what the
  existing `cmd_install` already does (it surfaces `mise doctor` output
  but doesn't abort on warnings).
- Adding `pnpm` or `bun` to the `dotfiles doctor` loop. That is a
  separate decision and out of scope here — this spec only covers
  `node`.
- Bumping the Node version inside a project's CI configuration, lockfile
  refresh, or any source-tree change beyond the dotfiles repo itself.

## Affected files

- `specs/006-node-via-mise.md` (new)
- `home/dot_config/mise/config.toml` (add `node = "lts"`)
- `bin/dotfiles` (add `node` to the `cmd_doctor` for-loop)
- `README.md` (Dev tools row + inline `[tools]` example)
- `tests/test_smoke.sh` (two new assertions: node in mise, node in doctor loop)
