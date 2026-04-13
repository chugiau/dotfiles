# 001 — Wire Claude Code statusline into settings.json

## Intent

`home/dot_claude/executable_statusline-command.sh` is correctly copied to
`~/.claude/statusline-command.sh` by chezmoi, but Claude Code never executes
it because `~/.claude/settings.json` lacks a `statusLine` block. The harness
needs that block to invoke the script. This spec covers an idempotent merge
step that adds the wiring without disturbing other fields (`hooks`,
`permissions`, `env`, …) that Claude Code itself maintains at runtime.

## Acceptance criteria

- After `chezmoi apply` (or `dotfiles install`), `~/.claude/settings.json`
  contains a `statusLine` object with:
  - `type` = `"command"`,
  - `command` = absolute path to `~/.claude/statusline-command.sh` (expanded
    against the current user's home directory at template-render time),
  - `padding` = `0`.
- If `~/.claude/settings.json` does not yet exist, the merge step creates it
  containing only the `statusLine` block.
- All other top-level keys in an existing `~/.claude/settings.json` (`env`,
  `hooks`, `permissions`, `autoMemoryEnabled`, …) are preserved; only the
  `statusLine` key is added or overwritten.
- If `statusLine` already equals the desired value, the script exits without
  rewriting the file (no mtime churn, deterministic re-runs).
- The chezmoi script is `run_onchange`, so changes to the wiring logic
  re-trigger it on the next `chezmoi apply`.
- `tests/test_smoke.sh` exercises the merge against fixture `settings.json`
  files and asserts both branches: missing file is created, and existing
  unrelated fields are preserved.

## Out of scope

- Managing the rest of `~/.claude/settings.json` from the dotfiles repo —
  hooks, permissions, env, etc. remain Claude-Code-managed.
- Templating or refactoring the statusline script itself; only the wiring
  is in scope.
- Cross-host secrets / Bitwarden interaction.

## Affected files

- `specs/001-claude-statusline-wireup.md` (new)
- `home/run_onchange_after_60-claude-statusline.sh.tmpl` (new)
- `tests/test_smoke.sh` (extend with merge-script behavioural test)
