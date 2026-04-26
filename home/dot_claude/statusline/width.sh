#!/usr/bin/env bash
# statusline/width.sh — terminal-column detection.
#
# Claude Code does not pass the terminal width into the regular statusline
# JSON payload (only the subagent statusline receives `columns`), and it
# spawns the statusline subprocess without a controlling terminal — so
# /dev/tty open fails, $COLUMNS is unset, and `tput cols` returns the
# 80-col terminfo default. We discover the real width by walking
# /proc/<pid>/fd/* on the parent-pid chain to find an ancestor's pty
# and running `stty size` against it. macOS lacks /proc; the existing
# /dev/tty + tput steps cover it.

# detect_columns_from_proc — Linux-only helper. Walks up the parent-pid
# chain (max 8 levels) looking for an fd that resolves to /dev/pts/* or
# /dev/tty[0-9]*; runs `stty size` against the first match. Prints the
# column count on success, returns non-zero (and prints nothing) on
# failure or on a non-/proc system.
detect_columns_from_proc() {
  [[ ! -d /proc ]] && return 1
  local pid=$$ depth pts cols fd
  for depth in 1 2 3 4 5 6 7 8; do
    pid=$(ps -o ppid= -p "${pid}" 2>/dev/null | tr -d ' ')
    [[ -z "${pid}" || "${pid}" -le 1 ]] && return 1
    for fd in 0 1 2; do
      pts=$(readlink "/proc/${pid}/fd/${fd}" 2>/dev/null)
      case "${pts}" in
        /dev/pts/*|/dev/tty[0-9]*)
          cols=$( { stty size <"${pts}"; } 2>/dev/null | awk '{print $2}' )
          if [[ -n "${cols}" ]] && [[ "${cols}" =~ ^[0-9]+$ ]] && [[ "${cols}" -gt 0 ]]; then
            printf "%s" "${cols}"
            return 0
          fi
          ;;
      esac
    done
  done
  return 1
}

# detect_columns — first non-zero positive integer in:
#   1. $CLAUDE_STATUSLINE_COLS  (test escape hatch / explicit override)
#   2. $COLUMNS                 (when the parent shell exports it)
#   3. stty size </dev/tty      (works when the subprocess has a ctty)
#   4. detect_columns_from_proc (recovers the real width via the parent
#                                pty when the subprocess has no ctty —
#                                this is the Claude Code case on Linux)
#   5. tput cols
#   6. literal 80
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

  # Wrap in a `{ …; } 2>/dev/null` group: bash processes redirections
  # left-to-right, so plain `</dev/tty 2>/dev/null` opens stdin first
  # and leaks the "No such device" error to the original stderr before
  # the 2>/dev/null takes effect.
  cols=$( { stty size </dev/tty; } 2>/dev/null | awk '{print $2}' )
  if [[ -n "${cols}" ]] && [[ "${cols}" =~ ^[0-9]+$ ]] && [[ "${cols}" -gt 0 ]]; then
    printf "%s" "${cols}"
    return
  fi

  cols=$(detect_columns_from_proc 2>/dev/null)
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
