#!/usr/bin/env bash
# statusline/core.sh — colours, formatters, width helpers.
#
# Sourced by the statusline entrypoint. Pure helpers, no I/O, no side
# effects beyond defining functions and ANSI-escape constants.

# ANSI colour escapes
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'
DIM='\033[2m'
BOLD='\033[1m'

# make_bar <pct 0-100> <width chars> — Unicode block progress bar.
make_bar() {
  local pct="${1:-0}"
  local width="${2:-10}"
  local filled=$(( (pct * width + 50) / 100 ))
  [[ "${filled}" -gt "${width}" ]] && filled="${width}"
  local empty=$(( width - filled ))
  local bar=""
  local i
  for (( i = 0; i < filled; i++ )); do bar="${bar}█"; done
  for (( i = 0; i < empty;  i++ )); do bar="${bar}░"; done
  printf "%s" "${bar}"
}

# compact_tokens <int> — 170234 → 170.2k, 1234567 → 1.2m, 999 → 999.
compact_tokens() {
  local n="${1:-0}"
  if [[ "${n}" -ge 1000000 ]]; then
    local whole=$(( n / 1000000 ))
    local frac=$(( (n % 1000000) / 100000 ))
    printf "%d.%dm" "${whole}" "${frac}"
  elif [[ "${n}" -ge 1000 ]]; then
    local whole=$(( n / 1000 ))
    local frac=$(( (n % 1000) / 100 ))
    printf "%d.%dk" "${whole}" "${frac}"
  else
    printf "%s" "${n}"
  fi
}

# truncate_name <name> <max> — appends "…" when length exceeds max.
truncate_name() {
  local name="${1}"
  local max="${2:-30}"
  if [[ "${#name}" -gt "${max}" ]]; then
    printf "%s" "${name:0:${max}}…"
  else
    printf "%s" "${name}"
  fi
}

# ansi_strip — read stdin, write the same text with ANSI CSI sequences removed.
ansi_strip() {
  sed 's/\x1b\[[0-9;]*m//g'
}

# visible_width <text> — character count after ANSI strip. Approximate; emoji
# and CJK glyphs render as 2 cols but count as 1 here. Item emitters should
# pre-compute their widths instead of measuring constructed strings.
visible_width() {
  local s
  s=$(printf "%s" "${1}" | sed 's/\x1b\[[0-9;]*m//g')
  printf "%s" "${#s}"
}

# format_active_time <ms> — "5m" or "1h 12m"; empty for <=0.
format_active_time() {
  local total_duration_ms="${1}"
  local active_secs=0
  if [[ -n "${total_duration_ms}" ]] && [[ "${total_duration_ms}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    active_secs=$(( ${total_duration_ms%%.*} / 1000 ))
  fi
  if [[ "${active_secs}" -le 0 ]]; then
    printf ""
    return
  fi
  local at_h at_m
  at_h=$(( active_secs / 3600 ))
  at_m=$(( (active_secs % 3600) / 60 ))
  if [[ "${at_h}" -gt 0 ]]; then
    printf "%s" "${at_h}h ${at_m}m"
  else
    printf "%s" "${at_m}m"
  fi
}

# format_api_duration <ms> — "42s", "2m 34s", "1h 3m 12s"; empty for <=0.
format_api_duration() {
  local ms="${1}"
  local total_secs=0
  if [[ -n "${ms}" ]] && [[ "${ms}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    total_secs=$(( ${ms%%.*} / 1000 ))
  fi
  if [[ "${total_secs}" -le 0 ]]; then
    printf ""
    return
  fi
  local h m s
  h=$(( total_secs / 3600 ))
  m=$(( (total_secs % 3600) / 60 ))
  s=$(( total_secs % 60 ))
  if [[ "${h}" -gt 0 ]]; then
    printf "%s" "${h}h ${m}m ${s}s"
  elif [[ "${m}" -gt 0 ]]; then
    printf "%s" "${m}m ${s}s"
  else
    printf "%s" "${s}s"
  fi
}

# format_reset_countdown <epoch> <unit:hm|dh> — "(resets in 2h 5m)", etc.
format_reset_countdown() {
  local reset_at="${1}"
  local unit="${2:-hm}"
  if [[ -z "${reset_at}" ]]; then
    printf ""
    return
  fi
  local now secs_left
  now=$(date +%s)
  secs_left=$(( reset_at - now ))
  if [[ "${secs_left}" -le 0 ]]; then
    printf "(resetting)"
    return
  fi
  if [[ "${unit}" == "dh" ]]; then
    local d h
    d=$(( secs_left / 86400 ))
    h=$(( (secs_left % 86400) / 3600 ))
    printf "(resets in %dd %dh)" "${d}" "${h}"
  else
    local h m
    h=$(( secs_left / 3600 ))
    m=$(( (secs_left % 3600) / 60 ))
    printf "(resets in %dh %dm)" "${h}" "${m}"
  fi
}

# pct_color <pct> — usage colour (low pct = green, high = red).
pct_color() {
  local pct="${1:-0}"
  if [[ "${pct}" -ge 90 ]]; then
    printf "%s" "${RED}"
  elif [[ "${pct}" -ge 80 ]]; then
    printf "%s" "${ORANGE}"
  elif [[ "${pct}" -ge 40 ]]; then
    printf "%s" "${YELLOW}"
  else
    printf "%s" "${GREEN}"
  fi
}

# cache_pct_color <pct> — cache-hit colour (high = green, low = red).
cache_pct_color() {
  local pct="${1:-0}"
  if [[ "${pct}" -ge 90 ]]; then
    printf "%s" "${GREEN}"
  elif [[ "${pct}" -ge 80 ]]; then
    printf "%s" "${YELLOW}"
  elif [[ "${pct}" -ge 40 ]]; then
    printf "%s" "${ORANGE}"
  else
    printf "%s" "${RED}"
  fi
}
