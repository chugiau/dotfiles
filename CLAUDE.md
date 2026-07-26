@AGENTS.md

## Claude-Specific

Procedural depth lives in `.claude/skills/`, not in `AGENTS.md`: the spec and
TDD process, the chezmoi source tree, the test suites, and the statusline. Load
the matching skill instead of re-deriving the procedure. `AGENTS.md` keeps a
usable short form of every rule because Codex reads it without skills, so treat
a skill as depth, never as the only copy of a rule.

`home/dot_claude/` is the Claude surface this repo owns — the statusline and the
`hooks/` sensitive-file guard. Both are deployed by `run_onchange_after_6*`
scripts, so an edit reaches a live session only after `chezmoi apply`.

The guard blocks closed when `jq` is missing, and it rejects prompts and tool
calls that reference `.ssh` or env-like paths. An unexpected rejection is
usually it; the fix is never to echo the path it objected to.
