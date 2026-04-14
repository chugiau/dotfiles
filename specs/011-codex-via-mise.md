# 011 — Install codex via mise

## Intent

[OpenAI Codex CLI](https://github.com/openai/codex) is the
terminal-native coding agent that ships alongside Claude Code in the
day-to-day toolbelt. Having it on `PATH` on every machine — same
cadence as `gh`, `glab`, `bun`, `pnpm` — means you can reach for the
two agents interchangeably without per-host install steps.

`codex` is first-class in mise's registry:

```
$ mise registry | grep '^codex'
codex    aqua:openai/codex    npm:@openai/codex
```

The aqua backend pulls a single static binary from the upstream
GitHub release, which means adding `codex = "latest"` to
`home/dot_config/mise/config.toml` drops it straight into
`~/.local/share/mise/shims/` on the next `dotfiles install`. No npm
global, no curl-pipe installer, no PATH shim of our own — the same
update cadence as the rest of the manifest.

This spec follows the spec-002 (pnpm) / spec-003 (bun) / spec-008
(gh + glab) precedent rather than spec 006 (node): `codex` is a leaf
tool whose absence is obvious the moment you type the command, so it
does **not** join the `bin/dotfiles doctor` loop. A missing `codex`
surfaces as "command not found", not as a cryptic LSP or hook failure,
so there is no debugging win from pre-flighting it in the doctor.

## Acceptance criteria

### `home/dot_config/mise/config.toml`

- Declares `codex = "latest"` under `[tools]`, pinned to `latest` to
  match the surrounding entries.
- The new line sits at the tail of the `[tools]` block, after the
  forge-CLI grouping (`gh`, `glab`), so the manifest visually groups
  file viewers → JS toolchain → forge CLIs → coding agents.

### `tests/test_smoke.sh`

- Asserts that `mise/config.toml` declares `codex` under `[tools]`,
  mirroring the existing `gh` / `glab` / `bun` assertions so a
  regression (someone deleting the line) is caught by the smoke suite.

### `README.md`

- The "What Gets Installed" table row for **Dev tools** lists `codex`
  alongside the existing mise-managed entries.
- The inline `[tools]` example block under "Tool management via mise"
  shows the `codex = "latest"` line, in the same position as the
  manifest.

## Out of scope

- Adding `codex` to the `bin/dotfiles doctor` loop — see the intent
  section for why (leaf-tool rationale, matches spec 002 / 003 / 008).
- Authenticating `codex` against the OpenAI API. That is a per-machine
  interactive step with no secret material to commit, and does not
  belong in a dotfiles spec. (API keys, if stored, ride the same age
  or Bitwarden-template flow documented in AGENTS.md § Secrets.)
- Shell completion wireups. oh-my-zsh already picks up completion
  from the mise shim PATH; nothing explicit to add here.
- Installing any related tools (Aider, Continue, other agents). Only
  `codex` itself.
- Touching `CLAUDE.md` / `AGENTS.md` — this is an additive leaf-tool
  change with no new repo convention to record.

## Affected files

- `specs/011-codex-via-mise.md` (new)
- `home/dot_config/mise/config.toml` (add `codex` line)
- `tests/test_smoke.sh` (one new assertion: codex in mise config)
- `README.md` (Dev tools row + inline `[tools]` example)
