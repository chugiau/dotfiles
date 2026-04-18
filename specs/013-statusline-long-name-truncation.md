# 013 — statusline long-name truncation

## Intent

Stop the Claude Code statusline from overflowing (and getting cut off
by the terminal's right edge, producing a dangling `…`) when a git
worktree directory or branch name is long. In practice this happens
routinely in teams whose branches encode ticket IDs + slug + author,
e.g. `20260417-493-exceed-rabbitmq-channels-tzuyao.chien-dev`.

Before this spec, line 1 rendered every name in full, three times
over: the folder basename was the worktree slug, the 🪵 segment
repeated it, and the 🌿 `git:(...)` segment carried
`worktree-<slug>`. The result ate the entire terminal width and
pushed the token counter and sub-agent badge off-screen, e.g.

```
🧠 [Opus 4.7 (1M context)] | 📁 <slug> 🪵 <slug> 🌿 git:(worktree-<slug>) | 2773…
                                                                          ↑ overflow
```

The fix introduces two changes to `statusline-command.sh`:

1. **`truncate_name` helper.** Caps any display string at a max
   visible length and appends `…` when it trims. Applied to the 🪵
   worktree slug (28 chars) and the 🌿 branch label (28 chars inside
   a worktree, 30 chars outside).
2. **Worktree-aware dedup.** When we're in a worktree, show
   `📁 <project-root-parent-basename>` (the repo directory, not the
   worktree slug) for the folder segment. Suppress the 🌿 branch
   segment entirely when the branch name redundantly encodes the
   worktree slug — any of: branch equals slug, branch equals
   `worktree-<slug>`, or branch contains slug as a substring.

The tracked copy of the statusline script in this dotfiles repo has
drifted behind the live `~/.claude/statusline-command.sh` copy over
several iterations; this spec's commit also re-syncs the full script,
not just the truncation hunks. The *spec* is narrowly about the
truncation + dedup behaviour — that is the behaviour this commit is
responsible for on the user's side — with the broader resync noted
in the commit body.

## Acceptance criteria

- `home/dot_claude/executable_statusline-command.sh` defines a
  `truncate_name` shell function that, given `(name, max)`, returns
  `name` unchanged when `${#name} <= max` and the first `max`
  characters followed by `…` otherwise.
- In worktree mode (`git_worktree` non-empty), the 🪵 segment applies
  `truncate_name "${git_worktree}" 28`.
- In worktree mode, the 🌿 branch segment is omitted when
  `git_branch` equals `git_worktree`, equals `worktree-<git_worktree>`,
  or contains `git_worktree` as a substring.
- In non-worktree mode, the 🌿 branch segment applies
  `truncate_name "${git_branch}" 30`.
- `tests/test_smoke.sh` covers the `truncate_name` contract (below-
  and above-threshold inputs) and the worktree/branch dedup
  suppression, sourcing the tracked script directly.
- `sh tests/test_smoke.sh` passes.

## Out of scope

- **Unicode width.** `${#name}` counts bytes-as-chars in bash, which
  is fine for the ASCII slug patterns this spec targets. Double-width
  CJK glyphs in branch names would still miscount; out of scope.
- **Line 2 / token-bar rendering.** Only line 1 overflows from
  long names. The usage bar, countdown, and sub-agent badge on
  line 2 are untouched.
- **Configurability.** The 28 / 30 caps are hard-coded. Exposing
  them via env var or settings.json would be overkill for a
  single-user dotfiles repo; out of scope.
- **The `run_onchange_after_60-claude-statusline.sh.tmpl` wiring
  script.** Already correct — it writes the `statusLine` block into
  `settings.json` idempotently. No change needed.
- **Re-architecting the statusline script.** The fix is additive
  (one helper + a conditional block); no refactor of the surrounding
  `build_line1` code.

## Affected files

- `specs/013-statusline-long-name-truncation.md` (new)
- `home/dot_claude/executable_statusline-command.sh` (full resync
  from the live `~/.claude/statusline-command.sh` copy — carries the
  `truncate_name` helper, the worktree-dedup block, and accumulated
  unrelated drift)
- `tests/test_smoke.sh` (new assertions: `truncate_name` contract,
  branch-suppression when branch encodes the worktree slug)
