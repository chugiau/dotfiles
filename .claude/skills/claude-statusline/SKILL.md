---
name: claude-statusline
description: Architecture of the Claude Code statusline shipped by this repo — the five sourced Bash modules under home/dot_claude/statusline/, the item record format, the five-line cap and priority dropping, terminal width detection, and the parallel PowerShell port. Load before changing anything under home/dot_claude/statusline*, adding a statusline item, or debugging statusline output.
---

# Claude statusline

A Claude Code statusline reads a JSON payload on stdin and prints the status
text. This repo's implementation is deliberately split into modules that share
state through globals, because it has to run under Bash 3.2 on macOS.

Design decisions live in `specs/021-responsive-statusline.md` (architecture),
`022` (width detection), `023` (session-state items), and `041` (Windows port).
Read the relevant spec before changing behavior.

## Layout

Entrypoint: `home/dot_claude/executable_statusline-command.sh`. It prepends a
fixed `PATH` prefix (the hook runs with a minimal environment), sources five
modules in a fixed order, and exits 0 with a message on stderr when `jq` is
missing — never a hard failure, because a broken statusline must not break the
session.

The order matters; later modules use what earlier ones define.

1. `statusline/core.sh` — ANSI constants, formatters, visible-width helpers.
   Pure functions, no I/O.
2. `statusline/data.sh` — `extract_fields` pulls the payload apart with `jq`:
   model, workspace, context window, and the session-state fields
   `.effort.level`, `.output_style.name`, `.thinking.enabled`, `.vim.mode`.
3. `statusline/width.sh` — terminal column detection.
4. `statusline/items.sh` — the `emit_*` functions that build the item list, plus
   `emit_all` which calls them in canonical display order.
5. `statusline/layout.sh` — packs items into lines.

Because the modules communicate through globals across a dynamic source path,
ShellCheck cannot follow the assignments; the disables at the top of the
entrypoint are intentional.

## Items

`item_push <id> <text> <visible_width> <priority>` appends a record to
`_ITEMS`, fields separated by `\x1f`. Two things are easy to get wrong:

- `text` carries ANSI escapes but `visible_width` must be the printable column
  count. Everything downstream sizes lines from that number.
- `priority` is the drop order. P0 survives everything; higher numbers are shed
  first.

Adding an item means writing an `emit_<thing>` function, calling it from
`emit_all` at the right position in the canonical order, and giving it a
priority that reflects how much you would miss it on a narrow terminal. An
emitter that has nothing to say prints nothing — `emit_output_style` stays
silent when the style is `default`, so the ✎ glyph never appears for it.

## Packing

`layout.sh` caps output at `LAYOUT_MAX_LINES=5` and joins items with `" | "`.
Dropping happens in two phases:

1. Preemptive — any non-P0 item wider than `width - 1` is dropped, since it
   could never fit on a line anyway.
2. Reactive — while the greedy wrap still exceeds five lines, drop the rightmost
   item of the highest priority number.

If P0 items alone overflow, nothing is dropped and the renderer ANSI-aware
truncates the trailing line instead.

## Width

`detect_columns` tries, in order: `$CLAUDE_STATUSLINE_COLS` (the override the
tests use), `$COLUMNS`, a `/proc` walk up the parent chain looking for a
`/dev/pts/*` to size, a `</dev/tty` probe, and finally the literal `80`. The
`/dev/tty` probe is wrapped in a `{ ...; } 2>/dev/null` group on purpose — an
unwrapped failure leaks an error into the statusline output.

## Windows

`home/dot_claude/statusline-command.ps1` plus `statusline-windows/Core.ps1`,
`Width.ps1`, `Data.ps1`, `Items.ps1`, `Layout.ps1` mirror the same structure.
Behavior changes should land on both sides or explicitly say why they do not.

## Deploying and testing

`run_onchange_after_60-claude-statusline.sh.tmpl` installs the Unix side;
`run_onchange_after_13-claude-statusline-windows.ps1.tmpl` the Windows side.

`tests/test_smoke.sh` drives the real entrypoint with fixture payloads at
several widths and asserts on the rendered output — module count, the five-line
cap, which items survive at width 40, and the presence of each session-state
field. Feed it a fixture through `CLAUDE_STATUSLINE_COLS` rather than mocking
the modules.
