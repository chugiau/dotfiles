#!/usr/bin/env bash
# statusline/width.sh — terminal-column detection.
#
# Claude Code does not pass the terminal width into the regular statusline
# JSON payload (only the subagent statusline receives `columns`). We
# discover it ourselves through this fallback chain, ending at a literal
# 80 — narrow enough not to assume a wide screen, wide enough that the
# P0+P1 set fits in two lines.

# detect_columns — first non-zero positive integer in:
#   1. $CLAUDE_STATUSLINE_COLS  (test escape hatch / explicit override)
#   2. $COLUMNS                 (when the parent shell exports it)
#   3. stty size </dev/tty      (works even when stdin is a pipe)
#   4. tput cols
#   5. literal 80
detect_columns() {
  local cols

  if [[ -n "${CLAUDE_STATUSLINE_COLS:-}" ]] \
     && [[ "${CLAUDE_STATUSLINE_COLS}" =~ ^[0-9]+$ ]] \
     && [[ "${CLAUDE_STATUSLINE_COLS}" -gt 0 ]]; then
    printf "%s" "${CLAUDE_STATUSLINE_COLS}"
    return
  fi

  if [[ -n "${COLUMNS:-}" ]] \
     && [[ "${COLUMNS}" =~ ^[0-9]+$ ]] \
     && [[ "${COLUMNS}" -gt 0 ]]; then
    printf "%s" "${COLUMNS}"
    return
  fi

  cols=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
  if [[ -n "${cols}" ]] && [[ "${cols}" =~ ^[0-9]+$ ]] && [[ "${cols}" -gt 0 ]]; then
    printf "%s" "${cols}"
    return
  fi

  cols=$(tput cols 2>/dev/null)
  if [[ -n "${cols}" ]] && [[ "${cols}" =~ ^[0-9]+$ ]] && [[ "${cols}" -gt 0 ]]; then
    printf "%s" "${cols}"
    return
  fi

  printf "80"
}
