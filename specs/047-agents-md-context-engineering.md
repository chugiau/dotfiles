# 047 — AGENTS.md Context Engineering For Claude 5

## Intent

Re-tune `AGENTS.md` for Claude 5 generation context engineering, following
Anthropic's guidance that an agent guidelines file should stay lightweight,
concentrate on codebase gotchas, avoid restating what an agent can read from
the file system, and rely on progressive disclosure instead of inlining every
detail.

Spec 032 already removed README-style background. This spec goes one step
further: it drops the remaining directory listing, deduplicates the command and
testing guidance, and points at `README.md` and `specs/` for depth instead of
repeating them.

## Acceptance criteria

- `AGENTS.md` keeps the behavior-changing workflow rules: spec-first, code-only
  TDD, spec-as-tiebreaker, per-logical-unit commits, and English artifacts.
- `AGENTS.md` keeps the full "easy to guess wrong" convention list, which is the
  gotcha content the guidance asks for.
- `AGENTS.md` no longer carries a `## Repo Map` section that describes files an
  agent can identify by reading the repository; the few non-obvious pointers in
  it are folded into the gotcha or command sections.
- Command and testing guidance appear once, not spread across three sections.
- `AGENTS.md` still mentions `Bats` and `dotfiles test`, which
  `tests/test_smoke.sh` asserts.
- `AGENTS.md` names `README.md` and `specs/` as the places to read for
  architecture and decision history.
- `CLAUDE.md` stays a single `@AGENTS.md` include, so no instruction is stored
  twice.
- `AGENTS.md` is shorter than the version it replaces.

## Out of scope

- Changing dotfiles behavior, hooks, shell modules, tests, or bootstrap scripts.
- Rewriting `README.md` or existing feature specs.
- Introducing repo-scoped Claude skills or other new agent infrastructure.
- Adding tests for this documentation-only change.

## Affected files

- `specs/047-agents-md-context-engineering.md`
- `AGENTS.md`
