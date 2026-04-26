#!/usr/bin/env bash
# statusline/width.sh — terminal-column detection.
#
# Claude Code does not pass the terminal width into the regular statusline
# JSON payload (only the subagent statusline receives `columns`). We
# discover it ourselves through this fallback chain, ending at a literal
# 80 — narrow enough not to assume a wide screen, wide enough that the
# P0+P1 set fits in two lines.
#
# The result is then floored at 24 columns. 24 is the minimum acceptable
# rendering width: the P0 ctx_bar (21 cols) fits on its own line with
# margin and the model item fits comfortably. Real terminals reporting
# sub-24 widths get a sane multi-line layout instead of nonsense
# zero-width truncation.

# detect_columns — first non-zero positive integer in:
#   1. $CLAUDE_STATUSLINE_COLS  (test escape hatch / explicit override)
#   2. $COLUMNS                 (when the parent shell exports it)
#   3. stty size </dev/tty      (works even when stdin is a pipe)
#   4. tput cols
#   5. literal 80
# clamped to >= 24.
detect_columns() {
  local cols=""

  if [[ -n "${CLAUDE_STATUSLINE_COLS:-}" ]] \
     && [[ "${CLAUDE_STATUSLINE_COLS}" =~ ^[0-9]+$ ]] \
     && [[ "${CLAUDE_STATUSLINE_COLS}" -gt 0 ]]; then
    cols="${CLAUDE_STATUSLINE_COLS}"
  elif [[ -n "${COLUMNS:-}" ]] \
     && [[ "${COLUMNS}" =~ ^[0-9]+$ ]] \
     && [[ "${COLUMNS}" -gt 0 ]]; then
    cols="${COLUMNS}"
  else
    local probe
    probe=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
    if [[ -n "${probe}" ]] && [[ "${probe}" =~ ^[0-9]+$ ]] && [[ "${probe}" -gt 0 ]]; then
      cols="${probe}"
    else
      probe=$(tput cols 2>/dev/null)
      if [[ -n "${probe}" ]] && [[ "${probe}" =~ ^[0-9]+$ ]] && [[ "${probe}" -gt 0 ]]; then
        cols="${probe}"
      else
        cols=80
      fi
    fi
  fi

  # Floor at the minimum acceptable rendering width.
  if [[ "${cols}" -lt 24 ]]; then
    cols=24
  fi

  printf "%s" "${cols}"
}
