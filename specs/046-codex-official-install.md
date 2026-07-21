# 046 — Install Codex CLI via the official installer on POSIX

## Intent

Spec 011 put `codex` under mise on POSIX/WSL2, betting on mise's bare
`codex = "latest"` shorthand resolving to the `aqua:openai/codex` static
binary backend. Spec 040 already stopped trusting that bet on native
Windows — the same shorthand ambiguity that made `eza` silently resolve to
`cargo:eza` there (spec 034) applies to `codex` too, and native Windows now
installs it directly via OpenAI's official installer instead of through
mise.

POSIX hosts should stop relying on the same unpinned-shorthand assumption.
Rather than pin the mise backend explicitly, POSIX now matches native
Windows and installs Codex CLI directly with OpenAI's official installer:

```sh
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

This drops the `codex` entry from mise's manifest entirely — mise no longer
manages Codex CLI on any platform — and adds a `run_once_after` script that
installs it the same way `home/run_once_after_12-codex-windows.ps1.tmpl`
already does for native Windows: skip if already on `PATH`, run the
installer, treat a failed install as a warning rather than a fatal error.
`dotfiles update` re-runs the installer to keep Codex current, mirroring how
`dotfiles.ps1 update` already refreshes it on native Windows.

## Acceptance criteria

### `home/dot_config/mise/config.toml`

- The `codex` line is removed from `[tools]` entirely. mise no longer
  installs or upgrades Codex CLI on any platform.

### `home/run_once_after_14-codex-install.sh.tmpl` (new)

- POSIX shell script (parses under `sh -n`).
- No-ops when `codex` is already resolvable on `PATH`.
- Otherwise runs `curl -fsSL https://chatgpt.com/codex/install.sh | sh`.
- A failed install (non-zero exit) is caught and surfaced as a warning, not
  a fatal error, matching `run_once_after_12-codex-windows.ps1.tmpl`.

### `home/.chezmoiignore`

- Native Windows ignores `14-codex-install.sh` by target script name,
  alongside the existing `10-mise-install.sh` / `15-neovim.sh` entries.

### `bin/dotfiles`

- `cmd_update` re-runs `curl -fsSL https://chatgpt.com/codex/install.sh | sh`
  when `codex` is on `PATH`, right after `mise upgrade`, matching the order
  `Invoke-Update` already uses in `bin/dotfiles.ps1`. A failed re-run does
  not abort the rest of `update`.

### `tests/test_smoke.sh`

- Replaces the "mise config declares codex under [tools]" / "mise config
  excludes codex from native Windows" assertions with one asserting `codex`
  is absent from `mise/config.toml` entirely.
- Asserts the new run script exists, parses under `sh -n`, no-ops when
  `codex` is already on `PATH`, runs the literal
  `curl -fsSL https://chatgpt.com/codex/install.sh | sh` command, and that
  `cmd_update` in `bin/dotfiles` re-runs the same command.
- Asserts `.chezmoiignore` ignores `14-codex-install.sh` on native Windows.

### `README.md`

- The "What Gets Installed" table's **Dev tools** row drops `codex` from
  the mise-managed list.
- A new sentence (mirroring the existing native-Windows Codex paragraph)
  states that POSIX/WSL2 also installs Codex CLI via the official
  installer, not mise, and both platforms now share that install method.
- The inline `[tools]` example block drops the `codex` line; the callout
  beneath it documents the official-installer flow for both platforms
  instead of describing an `os` filter that no longer exists.
- The tree listing under "Repo Map" adds
  `run_once_after_14-codex-install.sh.tmpl`.
- The "Updating" section's POSIX bullet list adds the Codex re-install step
  between `mise upgrade` and the oh-my-zsh upgrade.

## Out of scope

- Changing the native Windows install path — spec 040 stands unchanged.
- Adding `codex` to the `bin/dotfiles doctor` loop — unchanged leaf-tool
  rationale from spec 011.
- Authenticating Codex CLI — same out-of-scope note as spec 011.
- Pinning a specific Codex version — the official installer defaults to
  latest, matching the previous `"latest"` mise pin.

## Affected files

- `specs/046-codex-official-install.md` (new)
- `home/dot_config/mise/config.toml`
- `home/run_once_after_14-codex-install.sh.tmpl` (new)
- `home/.chezmoiignore`
- `bin/dotfiles`
- `tests/test_smoke.sh`
- `README.md`
