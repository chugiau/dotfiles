# 002 — Install pnpm via mise

## Intent

Some tools and Claude Code skills are distributed as npm packages and are
invoked through `pnpx` (pnpm's equivalent of `npx`) instead of `npx`. The
dotfiles repo currently manages its CLI toolchain through mise but does not
list `pnpm`, so a fresh machine has neither `pnpm` nor `pnpx` on `PATH`.

mise ships a core `pnpm` plugin that downloads the official standalone pnpm
binary — no separate Node.js runtime is required, and recent pnpm releases
still ship a `pnpx` entry point that forwards to `pnpm dlx`. Adding `pnpm`
to the mise manifest is therefore enough to make both `pnpm` and `pnpx`
available everywhere the rest of the toolchain already is.

## Acceptance criteria

- `home/dot_config/mise/config.toml` lists `pnpm` under `[tools]`, pinned to
  `latest` to match the other entries.
- After `dotfiles install` on a fresh machine, `mise install` materialises
  pnpm into `~/.local/share/mise/installs/pnpm/...` and shims both `pnpm`
  and `pnpx` into `~/.local/share/mise/shims` (which is already on `PATH`
  via the mise activation wired up in `dot_zshrc`).
- `tests/test_smoke.sh` asserts that `mise/config.toml` declares `pnpm`
  under the `[tools]` section, so dropping the entry regresses the smoke
  suite.
- No new shell aliases, wrapper scripts, or node/corepack installs are
  introduced — pnpm stands on its own via mise's core plugin.

## Out of scope

- Installing Node.js, npm, or corepack separately. pnpm's standalone binary
  is sufficient for the `pnpx` use case called out in the intent.
- Adding a `pnpx='pnpm dlx'` shell alias. If a future pnpm release removes
  the `pnpx` shim entirely, that can be revisited in a separate spec.
- Migrating existing skills or tools to invoke `pnpx` instead of `npx`;
  this spec only makes `pnpx` available.
- Touching the `doctor` loop in `bin/dotfiles`.

## Affected files

- `specs/002-pnpm-via-mise.md` (new)
- `home/dot_config/mise/config.toml` (add `pnpm` line)
- `tests/test_smoke.sh` (assert `pnpm` is declared under `[tools]`)
