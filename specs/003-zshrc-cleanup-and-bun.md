# 003 — Clean up dot_zshrc guards and install bun via mise

## Intent

Two problems to solve together:

1. `mise doctor` warns that `~/.bun/bin`, `~/.dotnet`, and `~/.dotnet/tools`
   are prepended to `$PATH` ahead of mise's shim directory, so if mise ever
   manages one of those tools the user would still get the shadow binary.
   The warning fires on this machine today even though neither `bun` nor a
   real `dotnet` install is present — `dot_zshrc` exports those `$PATH`
   entries unconditionally.

2. The zshrc is littered with tool setup blocks that fail loudly or silently
   on any machine without that tool. Each of `tofu`, `dotnet`, `fnm`,
   `pnpm`, `bun`, and Homebrew should load its env + completions only when
   the tool is actually present. `tofu`, `fnm`, and the first `pnpm` block
   already do the right thing; `dotnet`, `bun`, the duplicate `pnpm` block,
   and the linuxbrew `shellenv` call do not.

Adding `bun` to the mise manifest installs bun through the same toolchain as
the rest of the CLI tools, so the `~/.bun` standalone layout isn't needed for
a fresh machine — mise's shim is enough. The `~/.bun` block stays only as a
fallback for users who installed bun out of band via `curl … | bash`.

## Acceptance criteria

- `home/dot_config/mise/config.toml` lists `bun` under `[tools]`, pinned to
  `latest` to match the other entries, so `dotfiles install` materialises
  bun and shims it into `~/.local/share/mise/shims`.
- `home/dot_zshrc` guards the bun block behind `[ -x "$HOME/.bun/bin/bun" ]`
  and the dotnet block behind `[ -x "$HOME/.dotnet/dotnet" ]`, so neither
  touches `$PATH` on a machine without a standalone install.
- `home/dot_zshrc` wraps the Homebrew `shellenv` call in an existence check
  that covers macOS (`/opt/homebrew`, `/usr/local`) and Linuxbrew
  (`/home/linuxbrew/.linuxbrew`) layouts; machines without brew skip the
  `eval` entirely instead of erroring out.
- The duplicate unconditional `PNPM_HOME` block at the bottom of the file
  is removed — the guarded `command -v pnpm` block higher up already
  handles it.
- After these changes, `mise doctor` no longer reports the "mise tool
  paths are not first in PATH" warning on a machine with neither bun nor
  dotnet installed locally.
- `tests/test_smoke.sh` asserts:
  - `mise/config.toml` declares `bun` under `[tools]`.
  - `dot_zshrc` has no unguarded `~/.bun/bin` `$PATH` export.
  - `dot_zshrc` has no unguarded `~/.dotnet` `$PATH` export.
  - `dot_zshrc` has no unguarded linuxbrew `shellenv` call.
  - `dot_zshrc` contains exactly one `PNPM_HOME=` export (the guarded one).

## Out of scope

- Moving `mise activate` to the bottom of `dot_zshrc`. Guarding the
  offending blocks is enough to silence the `mise doctor` warning, and
  keeping `mise activate` near the top preserves the invariant that later
  `command -v` checks see mise shims.
- Replacing the `pkg-quarantine` wrapper functions for bun/pnpm/npm.
- Removing the leftover `~/.dotnet/corefx` directory — that is user-owned
  state, outside the dotfiles repo's purview.
- Changing how tofu, fnm, or the first pnpm block are guarded. They
  already only load on machines where the tool is present.

## Affected files

- `specs/003-zshrc-cleanup-and-bun.md` (new)
- `home/dot_config/mise/config.toml` (add `bun`)
- `home/dot_zshrc` (add guards, drop duplicate pnpm block)
- `tests/test_smoke.sh` (new assertions)
