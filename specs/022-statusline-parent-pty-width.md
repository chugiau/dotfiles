# 022 — statusline width detection via parent pty

## Intent

Fix a real-terminal regression introduced with spec 021: when Claude
Code spawns the statusline command, the subprocess does **not** inherit
a controlling terminal. `/dev/tty` open fails, `$COLUMNS` is unset (or
zero, depending on the host shell), and `tput cols` returns the 80-col
hard-coded default of the terminfo `cols#` capability when it can't
talk to a real tty. As a result, `detect_columns` reports `80` even
when the user's terminal is wider, the packer renders a single line
sized for an 80-col tty, and on terminals wider or narrower than 80
the line either wastes space or overflows the right edge — at narrow
widths (≤ 83 cols in the user's report) the visible result collapses
to one truncated row.

The fix is to read the actual terminal width through Linux's `/proc`
filesystem: walk up the parent-pid chain, find the first ancestor
whose stdin/stdout/stderr resolves to `/dev/pts/*` (the pty driver),
and run `stty size` against that path. This works because Claude
Code's parent process *does* hold the user's pty — the statusline
subprocess just can't see it via `/dev/tty`. On macOS (no `/proc`)
the chain falls through to the existing `stty size </dev/tty` and
`tput cols` steps as before.

This spec also fixes a stderr leak: `</dev/tty 2>/dev/null` is
order-significant — bash opens stdin first, so the open-failure error
("/dev/tty: No such device or address") goes to the original stderr,
*then* `2>/dev/null` redirects subsequent output. Wrapping the probe
in a `{ …; } 2>/dev/null` group fixes it.

## Acceptance criteria

### Width detection

- `home/dot_claude/statusline/width.sh` defines a new helper
  `detect_columns_from_proc` that:
  - Returns non-zero (and prints nothing) when `/proc` is absent
    (e.g. macOS).
  - Otherwise walks up the parent-pid chain at most 8 levels.
  - At each level, reads `/proc/<pid>/fd/0`, `fd/1`, and `fd/2`
    and accepts the first one that resolves to a path matching
    `/dev/pts/*` or `/dev/tty[0-9]*`.
  - Runs `stty size` against the matched path with stderr suppressed
    via a `{ …; } 2>/dev/null` group. Prints just the column count
    (the second whitespace-separated field) when it is a positive
    integer; returns non-zero otherwise.
- `detect_columns` consults the probes in this order:
  1. `$CLAUDE_STATUSLINE_COLS` — escape hatch.
  2. `$COLUMNS` — when exported, numeric, and `> 0`.
  3. `stty size </dev/tty` — wrapped in a `{ …; } 2>/dev/null` group
     to suppress the open-failure error when `/dev/tty` is not
     accessible.
  4. **NEW:** `detect_columns_from_proc` — recovers the real width
     when the subprocess has no ctty but a parent pid does.
  5. `tput cols`.
  6. Literal `80`.
- The `</dev/tty` open failure no longer prints
  `width.sh: line N: /dev/tty: No such device or address` to the
  caller's stderr.

### Behaviour invariants (unchanged from spec 021)

- `CLAUDE_STATUSLINE_COLS=300` → 1-line render with the test fixture.
- `CLAUDE_STATUSLINE_COLS=80`  → 2-5 lines, model + Context present.
- `CLAUDE_STATUSLINE_COLS=40`  → ≤ 5 lines, P2 'Weekly' bar dropped.
- All structural assertions for specs 013 / 014 / 017 / 018 / 021
  continue to pass.

### Tests (`tests/test_smoke.sh`)

- New assertions in the `[claude statusline (spec 022)]` block:
  - `detect_columns_from_proc` is defined in `width.sh`.
  - `width.sh` references `/proc/` (the parent-pty walk) and
    `/dev/pts/` (the pattern it matches against).
  - The `</dev/tty` probe is wrapped in `{ …; } 2>/dev/null` (the
    redirect leak fix). Asserted by greping for the literal
    `</dev/tty; } 2>/dev/null` or equivalent group form.
  - The fallback ordering literal `80` still appears.
- Behavioural sanity (gated on bash + jq):
  - With `CLAUDE_STATUSLINE_COLS` unset, `COLUMNS` unset, and stdin a
    pipe (no ctty), the script does not print the `/dev/tty: No
    such device or address` error to stderr. Asserted by piping
    stderr to a temp file and `grep -q "No such device"` returning
    non-zero.

## Out of scope

- **macOS-specific pty discovery.** macOS lacks `/proc`. The fallback
  chain still works through `stty size </dev/tty` (which generally
  succeeds on macOS Claude Code) and `tput cols`; no new macOS-only
  code path.
- **Probing widths via TIOCGWINSZ ioctl directly.** Bash has no
  built-in for ioctl; reading `stty size` against the matched path is
  equivalent and portable.
- **Caching the discovered width within a session.** The statusline
  re-renders frequently and the user can resize the terminal mid-
  session, so each run re-probes.
- **Inferring usable width from JSON or via a Claude-Code-set env
  var.** The payload does not carry a width field for the regular
  statusline; this is established in spec 021.

## Affected files

- `specs/022-statusline-parent-pty-width.md` (new)
- `home/dot_claude/statusline/width.sh`
  (`detect_columns_from_proc` helper, reordered fallback chain,
  `</dev/tty` redirect fix)
- `tests/test_smoke.sh` (new `[claude statusline (spec 022)]`
  block with structural + stderr-leak assertions)
