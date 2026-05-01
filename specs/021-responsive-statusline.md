# 021 — responsive statusline

## Intent

The Claude Code statusline currently renders three hard-coded lines from
three monolithic builders (`build_line1`, `build_line2`, `build_line3`)
in `home/dot_claude/executable_statusline-command.sh`. Display-item
order, separators, and grouping are baked into the prose of each
builder; the only "responsive" behaviour is a fixed 120-char overflow
threshold inside `build_line3` that pushes the timing segment to a
fourth line. The terminal-width information is never consulted, so:

- A wide terminal (>=200 cols) still gets three lines instead of one.
- A narrow terminal (<80 cols) still emits three full lines, which then
  wrap awkwardly and get truncated at the right edge by Claude Code's
  rendering layer — the user loses information they cannot see.
- Adding, removing, or reordering an item requires editing one of the
  three builders rather than touching a registry.

This spec replaces the line-builder model with a flat **item list**
fed into a width-aware **packer** that decides how many lines to emit
(1 to 5) and which low-priority items to drop when space is tight.

The Claude Code statusline JSON payload does **not** carry the
terminal width (verified against
<https://code.claude.com/docs/en/statusline> — only the *subagent*
statusline receives `columns`). The renderer detects width itself via
`stty size </dev/tty`, with a fallback chain.

## Acceptance criteria

### Architecture

- The entrypoint script `home/dot_claude/executable_statusline-command.sh`
  becomes a thin orchestrator: source modules, parse JSON, populate
  the item list, detect width, hand off to the packer, render. No
  display-item literals (emoji, ANSI strings, separators) live in the
  entrypoint.
- Display logic, helpers, and the layout engine live under
  `home/dot_claude/statusline/`:
  - `statusline/core.sh` — ANSI colour constants, `make_bar`,
    `compact_tokens`, `truncate_name`, `pct_color`, `cache_pct_color`,
    `ansi_strip`, `visible_width`, format-time helpers
    (`format_active_time`, `format_api_duration`,
    `format_reset_countdown`).
  - `statusline/data.sh` — `extract_fields` (JSON → globals),
    `collect_git_info`, `file_mtime`, `file_btime`,
    `compute_session_mins`, `count_claude_md`, `count_hooks`,
    `count_subagents`.
  - `statusline/width.sh` — `detect_columns` with the fallback chain
    described below.
  - `statusline/items.sh` — every `emit_<id>()` function. Each emit
    function pushes zero or one record into the global `_ITEMS` array
    via `item_push`; nothing knows about lines.
  - `statusline/layout.sh` — `layout_pack` (drop-then-greedy-wrap)
    and `layout_render` (emit lines joined by ` | `).
- `statusline/lib/` and `statusline/items/` directory shapes are *not*
  required — a single tier under `statusline/` is sufficient and
  keeps sourcing fast.

### Item-list data model

- An item record is encoded as a single string with US (Unit
  Separator, `\x1f`) delimiters: `id\x1ftext\x1fwidth\x1fpriority`.
  This avoids bash 3.2's lack of associative arrays without forcing a
  parallel-array scheme.
- `item_push <id> <text> <visible_width> <priority>` appends to a
  global `_ITEMS` indexed array. `text` carries ANSI escapes;
  `visible_width` is the rendered column count *excluding* ANSI and
  is computed by the emitter (cheaper and more accurate than measuring
  an emoji-laden string at render time).
- Priority levels:
  - `0` — always rendered; truncate before drop.
  - `1` — important (folder, branch, total tokens, ctx percent).
  - `2` — useful (cost, version, rate-limit bars, ahead/behind, git
    staged/modified counts).
  - `3` — nice-to-have (untracked count, +/- line stats, cache hit %,
    in/out current-call tokens, CLAUDE.md count, hook count,
    sub-agent badge, ⚡ active / ⏱ api / 🕐 session timings).

### Items emitted (in canonical left-to-right order)

`model` (P0) · `vim_mode` (P1, when present) · `folder` (P1) ·
`worktree` (P1, when present) ·
`branch` (P1, when present) · `ahead_behind` (P2) · `git_staged` (P2) ·
`git_modified` (P2) · `git_untracked` (P3) · `git_lines` (P3) ·
`total_tokens` (P1) · `subagents` (P3, when count>0) ·
`ctx_bar` (P0) · `ctx_pct` (P1) ·
`five_hour` (P2, when present) · `seven_day` (P2, when present) ·
`version` (P2) ·
`effort` (P2, when present) · `output_style` (P3, when non-default) ·
`thinking` (P3, when enabled) ·
`claude_md` (P3) · `hooks` (P3) ·
`cache_pct` (P3, when current_usage present) ·
`in_out` (P3, when current_usage present) ·
`cost` (P2, when non-zero) ·
`active_time` (P3, when non-zero) ·
`api_duration` (P3, when non-zero) ·
`session_mins` (P3, when >0).

*(`vim_mode`, `effort`, `output_style`, `thinking` added by spec 023.)*

### Width detection

`detect_columns()` in `statusline/width.sh` returns the first non-zero
positive integer from this chain:

1. `$CLAUDE_STATUSLINE_COLS` env var (escape hatch for tests).
2. `$COLUMNS` env var.
3. `stty size </dev/tty 2>/dev/null` second column.
4. `tput cols 2>/dev/null`.
5. Literal `80` (the spec's chosen fallback — narrow enough that we do
   not assume a wide screen, wide enough to render the P0 + P1 set in
   2 lines without truncation).

### Packer

`layout_pack <width> <max_lines>` (with `max_lines = 5`) walks the
item list and produces a 2-D plan:

1. Compute total visible width of all items plus ` | ` separators
   (3 cols each between two adjacent items on the same line).
2. **Drop phase** — while the rough capacity (`width × max_lines`,
   minus a per-line slack for separators) is exceeded, drop the
   highest-numbered priority item (ties: drop the rightmost first).
   P0 items are never dropped.
3. **Wrap phase** — greedy left-to-right pack. For each item: if
   adding it (with leading ` | ` separator when the line is non-empty)
   would push the line past `width - 1` (1-col safety margin), start
   a new line. If a single item alone exceeds `width - 1`, place it
   on its own line; the renderer will ANSI-aware truncate it with `…`.
4. **Hard cap** — if the wrap phase would exceed `max_lines`, drop
   further P3 → P2 items and re-wrap. If after dropping every P3 and
   P2 item the plan still overflows (i.e. P0/P1 alone exceeds 5
   lines), truncate the trailing line with `…`.

The renderer (`layout_render`) joins each line's items with ` | `,
applies ANSI-aware truncation when an item or final line exceeds
`width`, and prints lines separated by `\n`. Total output is at most
`max_lines` lines and each visible line is at most `width` columns.

### Behaviour invariants

- Output line count is **dynamic** — 1 line on a wide screen, up to
  5 on a narrow one. There is no longer a fixed three-line format.
- At terminal width 200 the model + folder + branch + ctx bar +
  total tokens + version all fit on a single line.
- At terminal width 40 only P0 items render (model, ctx bar) and
  the line is truncated with `…` if it still exceeds 40.
- At terminal width 80 (the fallback default) the P0 + P1 set fits
  in at most two lines.
- Items emit in the canonical order regardless of which are dropped —
  drops never reorder survivors.

### Tests (`tests/test_smoke.sh`)

- New `[claude statusline (spec 021)]` block:
  - The five module files exist and parse with `bash -n`:
    `home/dot_claude/statusline/{core,data,width,items,layout}.sh`.
  - `detect_columns` is defined in `statusline/width.sh` and the
    fallback literal `80` appears in its body.
  - `_ITEMS` array and `item_push` helper are defined in
    `statusline/items.sh`.
  - `layout_pack` and `layout_render` are defined in
    `statusline/layout.sh` and reference `max_lines` of `5`.
  - The entrypoint sources all five modules.
- Behavioural (run under bash 3.2+, gated on `bash` availability):
  - Feed a fixture JSON via stdin with `CLAUDE_STATUSLINE_COLS=200`
    and assert the output has exactly 1 line containing the model
    name and the context bar.
  - Same fixture with `CLAUDE_STATUSLINE_COLS=80` → output has
    between 2 and 5 lines and contains `Context` (the P0 ctx bar
    label) plus the model name.
  - Same fixture with `CLAUDE_STATUSLINE_COLS=40` → output has at
    most 5 lines, every visible line is ≤ 40 columns once ANSI
    escapes are stripped, and the model name appears.
  - With no env var override and `/dev/tty` unavailable
    (`</dev/null`), the script still produces output (does not
    error) and contains the model name — proving the 80 fallback
    works.
- Existing structural assertions for specs 013 / 014 / 017 / 018
  must continue to pass; they are updated to grep the new module
  files where the helper they assert about now lives:
  - `truncate_name` → `statusline/core.sh`
  - `format_api_duration` → `statusline/core.sh`
  - `file_btime`, `compute_session_mins` → `statusline/data.sh`
  - `git_ahead` / `git_behind` initialisation, ↑ / ↓ markers,
    `truncate_name "${git_worktree}" 28`, `truncate_name "${git_branch}" 30`
    → wherever they end up across `statusline/data.sh` and
    `statusline/items.sh`.

## Out of scope

- **wcwidth-correct CJK / emoji column counting.** Each emitter
  precomputes its own visible width using a simple model
  (ASCII = 1, our known emoji set = 2). Branch / folder names that
  themselves contain CJK still miscount; out of scope.
- **Per-item user configuration.** Priorities and the canonical
  order are hard-coded in `statusline/items.sh`. A config file or
  env-var DSL is overkill for a single-user dotfiles repo.
- **Live-copy sync to `~/.claude/statusline-command.sh` and the new
  `~/.claude/statusline/` tree.** Handled by `chezmoi apply`.
- **Rewriting in another language** (Python, Go, Bun). Bash startup
  latency matters for a statusline that re-renders on every tick;
  staying in bash with a structured array is faster.
- **The `run_onchange_after_60-claude-statusline.sh.tmpl` wireup.**
  Already correct — it sets `settings.json.statusLine.command` to
  the same `~/.claude/statusline-command.sh` path. No change needed.
- **Visual redesign** (icon swaps, colour scheme changes). Items and
  their visual encoding match the pre-spec output one-for-one; the
  refactor is structural.

## Affected files

- `specs/021-responsive-statusline.md` (new)
- `home/dot_claude/executable_statusline-command.sh` (rewritten as
  a ~50-line entrypoint)
- `home/dot_claude/statusline/core.sh` (new)
- `home/dot_claude/statusline/data.sh` (new)
- `home/dot_claude/statusline/width.sh` (new)
- `home/dot_claude/statusline/items.sh` (new)
- `home/dot_claude/statusline/layout.sh` (new)
- `tests/test_smoke.sh` (new spec-021 block; existing spec-013 /
  014 / 017 / 018 blocks updated to grep the new module locations)
