# 049 — Agent Skills Configuration

## Intent

The installed engineering skills (`to-tickets`, `triage`, `to-spec`,
`wayfinder`, `domain-modeling` and friends) are per-repo configurable: each one
needs to know where issues live, which label strings mark the triage states, and
where domain documentation sits. Nothing in this repo answered those questions,
so every invocation would have guessed — and guessed differently each time.

Record the three answers as checked-in files under `docs/agents/`, and point at
them from `CLAUDE.md`, so the contract is read rather than inferred.

Two boundaries matter more than the answers themselves:

- **`specs/` stays the authority for in-repo change proposals.** Declaring an
  issue tracker gives the skills a place to publish tickets; it does not retire
  the spec-first workflow and does not make an issue a precondition for a spec.
- **`docs/` is outside the chezmoi source tree.** `.chezmoiroot` is `home`, so
  these files are repo documentation only and never render into `$HOME`.

## Acceptance criteria

- `docs/agents/issue-tracker.md` declares GitHub Issues driven by the `gh` CLI,
  and carries the `PRs as a request surface: no` flag so external PRs stay out
  of the triage queue.
- `docs/agents/triage-labels.md` maps the five canonical roles — `needs-triage`,
  `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix` — to identical
  label strings.
- `docs/agents/domain.md` declares a single-context layout: `CONTEXT.md` plus
  `docs/adr/` at the repo root, with agents proceeding silently when those files
  are absent.
- `docs/agents/domain.md` records that `specs/` remains the authority for
  in-repo change proposals.
- `CLAUDE.md` gains an `## Agent skills` section with one sub-block per config
  file, each pointing at its `docs/agents/` path.
- `AGENTS.md` is unchanged and stays tool-agnostic; the pointer lives in
  `CLAUDE.md` because only Claude runs these skills.
- `tests/test_smoke.sh` asserts the three config files, the GitHub/`gh`
  declaration, the PR flag default, the five label strings, the single-context
  declaration, and the `CLAUDE.md` pointers.

## Out of scope

- Creating `CONTEXT.md` or `docs/adr/` now. `domain-modeling` creates them
  lazily when terms or decisions actually get resolved.
- Migrating `specs/` into GitHub Issues, or requiring an issue before a spec.
- Enabling external pull requests as a triage surface.
- Codex-side configuration. `home/dot_codex/` and `AGENTS.md` are untouched.
- Deploying anything to `$HOME`. `docs/` sits at the repo root, outside `home/`.

## Affected files

- `specs/049-agent-skills-config.md`
- `docs/agents/issue-tracker.md`
- `docs/agents/triage-labels.md`
- `docs/agents/domain.md`
- `CLAUDE.md`
- `tests/test_smoke.sh`
