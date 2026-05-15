# 032 — Agent Guidelines Token Efficiency

## Intent

Keep `AGENTS.md` focused on instructions that change agent behavior in this
repository. The file should preserve project-specific rules and non-obvious
local conventions while removing README-style background that an agent can infer
from the repository or general tool knowledge.

## Acceptance criteria

- `AGENTS.md` keeps the SDD, scoped TDD, proactive commit, and English-artifact
  rules.
- `AGENTS.md` calls out the repository conventions that agents are likely to
  guess incorrectly, including the chezmoi runtime/source split, shell startup
  split, mise PATH ordering, Neovim's system-wide install, retired pnpm, direnv
  ordering, sensitive-file policies, and chezmoi-native secrets workflow.
- `AGENTS.md` keeps the core command and test entrypoints without duplicating
  the long README architecture guide.
- `AGENTS.md` remains shorter and more instruction-dense than the previous
  README-style version.

## Out of scope

- Changing dotfiles behavior, hooks, shell modules, tests, or bootstrap scripts.
- Rewriting `README.md` or existing feature specs.
- Adding tests for this documentation-only change.

## Affected files

- `specs/032-agent-guidelines-token-efficiency.md`
- `AGENTS.md`
