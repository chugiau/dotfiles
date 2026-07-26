# 048 — Progressive Disclosure Via Repo Skills

## Intent

Complete the Claude 5 context engineering pass started in spec 047 by applying
the remaining two pieces of Anthropic's recommended layering: move procedural
depth out of the always-loaded guidelines file into repo-scoped skills that
Claude loads on demand, and give Claude-only material its own layer in
`CLAUDE.md` instead of mixing it into the tool-agnostic `AGENTS.md`.

The split is by kind of content, not by topic:

- **Gotchas stay always-loaded.** A warning only works if it is in context
  before the agent acts, so the "easy to guess wrong" list stays in `AGENTS.md`.
- **Procedures become skills.** "How do I add a test", "how do I get an edit
  into `$HOME`", "how do I write a spec" are only needed once the agent has
  decided to do that thing, which is what progressive disclosure is for.

`AGENTS.md` must keep a working minimum of every rule so that agents without
skill support (currently Codex) still behave correctly from it alone. Skills add
depth; they do not hold the only copy of a rule.

## Acceptance criteria

- Four repo-scoped skills exist under `.claude/skills/<name>/SKILL.md`, each
  with YAML frontmatter carrying `name` and `description`:
  - `spec-driven-change` — spec numbering, section-by-section template, the
    Red/Green commit sequence, and when a change is trivial enough to skip.
  - `chezmoi-source-tree` — chezmoi source-file naming, the run-script
    ordering scheme, the platform ignore split, and the edit/apply loop.
  - `dotfiles-test-suite` — layout of `tests/test_smoke.sh`, its helpers, how to
    add an assertion block, the Bats suite, and the static gates.
  - `claude-statusline` — Claude-only statusline module architecture, the
    five-line cap, priority dropping, and its deploy path.
- Each skill `description` states when to load it, so Claude can select it
  without the body being in context.
- `CLAUDE.md` includes `@AGENTS.md` and adds a Claude-only section covering the
  `.claude/skills/` pointer and the `home/dot_claude/` surface.
- `AGENTS.md` stays tool-agnostic: no `.claude/` paths, no Claude-only surfaces.
- `AGENTS.md` still states every workflow rule in a usable short form, still
  mentions `Bats` and `dotfiles test`, and keeps the full gotcha list.
- `AGENTS.md` is shorter than after spec 047.
- `tests/test_smoke.sh` asserts the skill files, their frontmatter keys, and the
  `CLAUDE.md` layering.

## Out of scope

- Codex-side skills or any `home/dot_codex/` change. Codex keeps working from
  `AGENTS.md` alone until a later spec ports the same depth.
- A skill for the sensitive-file guard hooks; the gotcha summary in `AGENTS.md`
  remains the only guidance for now.
- Changing dotfiles behavior, hooks, shell modules, or bootstrap scripts.
- Deploying these skills to `$HOME`; they are repo-scoped and stay at the repo
  root, outside the chezmoi source tree.

## Affected files

- `specs/048-progressive-disclosure-skills.md`
- `.claude/skills/spec-driven-change/SKILL.md`
- `.claude/skills/chezmoi-source-tree/SKILL.md`
- `.claude/skills/dotfiles-test-suite/SKILL.md`
- `.claude/skills/claude-statusline/SKILL.md`
- `CLAUDE.md`
- `AGENTS.md`
- `tests/test_smoke.sh`
