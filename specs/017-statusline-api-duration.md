# 017 — statusline API duration display

## Intent

Surface the cumulative time Claude Code has spent on round-trip API
calls during the current session. It complements the existing ⚡ active
time (total Claude thinking/working time) and 🕐 session wall-clock
age by answering a distinct question: *how much of this session has
been spent waiting on the network / the model?*

A new segment renders on line 3 between ⚡ and 🕐:

    ⚡ <active> | ⏱ <api_duration> | 🕐 <session_mins>m

The value is pulled from `cost.total_api_duration_ms` in the statusline
JSON payload and formatted as `Xs`, `Xm Ys`, or `Xh Ym Zs` — matching
the existing time formatting style — so brief sessions stay compact
and long ones remain readable.

## Acceptance criteria

- `extract_fields` in `home/dot_claude/executable_statusline-command.sh`
  reads `.cost.total_api_duration_ms` into a global
  `total_api_duration_ms` (empty when absent).
- A `format_api_duration` helper converts a millisecond value to a
  human-readable string: `2m 34s`, `1h 3m 12s`, `42s`. It returns an
  empty string for `0`, empty input, or non-numeric input.
- `build_line3` accepts the formatted string as its 6th argument and,
  when non-empty, inserts `⏱ <api_duration>` into the timing segment
  between the ⚡ active-time and 🕐 session-age parts.
- When `total_api_duration_ms` is absent or zero, the line-3 output is
  unchanged from before this spec (no empty ⏱ segment, no stray pipe).
- The existing line-3 overflow rule (timing segment drops to its own
  line when total visible width would exceed 120 chars) continues to
  work with the extra part present.
- `tests/test_smoke.sh` asserts structurally that:
  - `extract_fields` reads `total_api_duration_ms`.
  - `format_api_duration` is defined.
  - `build_line3` renders the `⏱` marker.
  - `main` wires `api_duration_str` into the `build_line3` call.
- `sh tests/test_smoke.sh` continues to pass.

## Out of scope

- **Per-call latency stats** (p50 / p99 / last call). Only the session
  cumulative is shown.
- **Color coding by duration.** The segment is plain text, like 🕐.
- **Configurable icon.** `⏱` is hard-coded.
- **Line 1 or line 2.** Only line 3 changes.
- **Live-copy sync to `~/.claude/statusline-command.sh`.** Handled by
  `chezmoi apply`; not a spec concern.

## Affected files

- `specs/017-statusline-api-duration.md` (new)
- `home/dot_claude/executable_statusline-command.sh`
  (`extract_fields`, `format_api_duration`, `build_line3`, `main`)
- `tests/test_smoke.sh` (new assertions under
  `[claude statusline (spec 017)]`)
