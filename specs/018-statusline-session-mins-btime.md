# 018 — statusline session-minutes uses file birth time

## Intent

The 🕐 wall-clock "session age" indicator on line 3 has been reading `0m`
for the entire session. Root cause: `compute_session_mins` bases its
calculation on the transcript file's `mtime`, but Claude Code appends
to the transcript on every message, so `mtime` is effectively "now" and
`(now - mtime) / 60` always rounds to 0.

Switch to the file's **birth time** (creation time) so the counter
reflects how long ago the session actually started. Not every Linux
filesystem reports birth time reliably — on those we fall back to the
first JSONL line's `timestamp` field (Claude Code transcripts are
append-only JSONL and the first line is the session-start event), and
finally to `mtime` as a last-resort guarantee of non-empty output.

## Acceptance criteria

- A new `file_btime` helper in
  `home/dot_claude/executable_statusline-command.sh` returns the file's
  birth time as Unix epoch seconds, with this fallback chain:
  1. `stat -c %W` (Linux) or `stat -f %B` (macOS/BSD)
  2. if the above yields empty, `0`, or `-`: parse the `timestamp`
     field from the first line of the file (assumed JSONL)
  3. if that also fails: fall back to `file_mtime`
- `compute_session_mins` uses `file_btime` instead of `file_mtime` for
  its calculation.
- The result is clamped to `>= 0` (a negative elapsed value — which
  can occur if clocks disagree — becomes 0).
- Non-numeric birth-time values (e.g. literal `-` from older stat) are
  rejected before entering the arithmetic expansion, so the helper
  cannot abort on `((` syntax errors.
- `tests/test_smoke.sh` asserts structurally that:
  - `file_btime` helper is defined.
  - `compute_session_mins` references `file_btime` (not only
    `file_mtime`).
  - The fallback to the JSONL `timestamp` field is wired up.
- `sh tests/test_smoke.sh` continues to pass.

## Out of scope

- **Showing seconds or hours.** The display stays at whole minutes.
- **Showing a human-friendly label like "2h ago".** The `🕐 Nm` form
  is retained.
- **Replacing JSONL parsing with a more robust parser.** The first-line
  `timestamp` lookup is a best-effort fallback, not a contract.
- **Live-copy sync to `~/.claude/statusline-command.sh`.** Handled by
  `chezmoi apply`.

## Affected files

- `specs/018-statusline-session-mins-btime.md` (new)
- `home/dot_claude/executable_statusline-command.sh`
  (new `file_btime` helper; `compute_session_mins` switched from
  `file_mtime` to `file_btime`; clamp + numeric guard)
- `tests/test_smoke.sh` (new assertions under
  `[claude statusline (spec 018)]`)
