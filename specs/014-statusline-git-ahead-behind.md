# 014 — statusline git ahead/behind counters

## Intent

Surface the upstream sync state of the current branch directly in the
Claude Code statusline so the developer can see at a glance whether
local commits need pushing or remote commits need pulling, without
leaving the editor.

Two new counters appear on line 1, immediately after the branch label:

- **ahead** — number of local commits not yet pushed to the tracking
  remote (e.g. `↑3` means 3 commits ahead)
- **behind** — number of remote commits not yet pulled into the local
  branch (e.g. `↓2` means 2 commits behind)

Both are hidden when their count is zero, so the statusline stays
compact on a clean branch.

## Acceptance criteria

- `collect_git_info` in `executable_statusline-command.sh` sets two new
  globals: `git_ahead` (integer ≥ 0) and `git_behind` (integer ≥ 0).
- The values are populated via
  `git rev-list --count HEAD...@{u}` (or equivalent left/right
  counting) when an upstream tracking branch is configured; both default
  to `0` when no upstream exists or the command fails.
- `build_line1` renders `↑<ahead>` in green immediately after the
  branch/worktree label when `git_ahead > 0`.
- `build_line1` renders `↓<behind>` in red immediately after the branch
  label (and after the `↑` segment if also ahead) when `git_behind > 0`.
- When both are zero the statusline output is identical to the pre-spec
  output (no extra characters).
- `tests/test_smoke.sh` asserts that:
  - `collect_git_info` defines `git_ahead` and `git_behind` (structural
    grep on the source).
  - The `↑` segment appears in `build_line1` output (structural grep).
  - The `↓` segment appears in `build_line1` output (structural grep).
- `sh tests/test_smoke.sh` continues to pass.

## Out of scope

- **Fetch before counting.** The script never runs `git fetch`; it only
  reads the last-known remote-tracking ref. Keeping the statusline
  low-latency (no network calls) is more important than absolute
  freshness.
- **Diverged / detached HEAD states.** If HEAD is detached,
  `git_ahead` and `git_behind` remain 0; no special indicator is added.
- **Configurable symbols.** The `↑`/`↓` characters are hard-coded.
- **Line 2 / context bar.** Only line 1 is changed.

## Affected files

- `specs/014-statusline-git-ahead-behind.md` (new)
- `home/dot_claude/executable_statusline-command.sh` (ahead/behind
  collection in `collect_git_info`; display in `build_line1`)
- `~/.claude/statusline-command.sh` (live copy, synced from tracked)
- `tests/test_smoke.sh` (new assertions under `[claude statusline
  (spec 014)]`)
