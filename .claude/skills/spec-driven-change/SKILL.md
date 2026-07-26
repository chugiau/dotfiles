---
name: spec-driven-change
description: How this repo runs spec-driven development and TDD — picking the next spec number, what belongs in each spec section, the Red/Green commit sequence, and when a change is trivial enough to skip the spec. Load before starting any non-trivial change to the dotfiles repo, or when a spec, test, and implementation disagree.
---

# Spec-driven change

Every non-trivial change here starts as a spec, becomes a failing test, then
becomes code. The spec is the durable artifact: tests and implementation are
derived from it and lose the argument when they disagree.

## Writing the spec

Number is the next free integer in `specs/`, zero-padded to three digits, with a
kebab-case slug: `specs/048-progressive-disclosure-skills.md`. Read the two or
three most recent specs before writing — they set the expected depth, and they
show how much of the "why" belongs in `## Intent`.

Four required sections:

- `## Intent` — the problem and the reasoning. This is where a future reader
  learns why the repo is the way it is, so state the motivation, not just the
  change. Prose, not bullets, when the reasoning has any nuance.
- `## Acceptance criteria` — checkable statements, each one something a test or
  a careful reader can verify. Write them so a grep assertion could be derived
  from them; that is usually what happens next.
- `## Out of scope` — the adjacent work you are deliberately not doing.
  Non-negotiable when the change touches a shared surface, because it is what
  stops the next agent from "finishing" something you decided against.
- `## Affected files` — every file the change will touch, including the spec
  itself and the tests.

Specs are append-only in spirit: when behavior should change, edit the spec
first in its own commit, then follow with tests and code.

## Trivial changes

A typo fix, a version bump, or a one-line correction does not need a spec file.
Put `Spec: <one sentence>` in the commit body instead. If you find yourself
writing more than a sentence, it was not trivial — write the spec.

## Red then Green

Code changes follow Red -> Green -> Refactor, and the sequence shows up in the
commit history:

1. `test: assert <behavior> (spec NNN, red)` — add the assertion, run the suite,
   confirm it fails for the stated reason. A test that passes before the
   implementation is not testing the new behavior.
2. `fix|feat: <change> (spec NNN, green)` — the smallest change that makes it
   pass.
3. Refactor separately if needed.

Documentation and other non-code work skips TDD entirely — but documentation
that encodes a decision often still deserves a grep assertion, because that is
how this repo keeps decisions from silently regressing. See the
`dotfiles-test-suite` skill for how to write one.

## Commit discipline

Commit each logical unit as you finish it rather than batching. Spec, test, and
implementation are separate commits by default. Commit messages, like every
other artifact here, are English.
