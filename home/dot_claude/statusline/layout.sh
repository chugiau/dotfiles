#!/usr/bin/env bash
# statusline/layout.sh — pack item records into at most max_lines = 5
# output lines, dropping low-priority items (P3 → P2 → P1, rightmost
# first within a tier) while respecting the canonical order. The
# renderer ANSI-aware truncates the trailing line when even the
# survivors overflow.

LAYOUT_MAX_LINES=5
LAYOUT_SEP=" | "
LAYOUT_SEP_W=3

# layout_pack <width>
#
# Reads global _ITEMS, writes globals _PLAN_LINES (joined-text per line,
# with ANSI) and _PLAN_WIDTHS (visible-column count per line). Drops
# happen in two phases:
#   1. Preemptive: any non-P0 item whose own visible width exceeds
#      (width-1) is dropped — it can't fit on a single line and would
#      be truncated by the renderer anyway. Keeps the display compact
#      on narrow terminals.
#   2. Reactive: while the greedy wrap exceeds max_lines, drop the
#      rightmost item with the highest priority number. P0 items are
#      never dropped; if they alone overflow, the renderer truncates.
layout_pack() {
  local width="${1}"
  local max_lines="${LAYOUT_MAX_LINES}"
  local line_cap=$(( width - 1 ))

  _PACK_WORK=()
  local i rec w prio
  for (( i = 0; i < ${#_ITEMS[@]}; i++ )); do
    rec="${_ITEMS[i]}"
    w="${rec%$'\x1f'*}"
    w="${w##*$'\x1f'}"
    prio="${rec##*$'\x1f'}"
    if [[ "${prio}" -eq 0 ]] || [[ "${w}" -le "${line_cap}" ]]; then
      _PACK_WORK+=("${rec}")
    fi
  done

  # Drop loop: while greedy-wrap exceeds max_lines, drop the rightmost
  # item with the highest priority number (P3 first, then P2, then P1).
  while :; do
    layout_pack_once "${width}"
    if [[ "${_PACK_LINES}" -le "${max_lines}" ]]; then
      break
    fi

    local drop_idx=-1 drop_prio=0 i prio
    for (( i = ${#_PACK_WORK[@]} - 1; i >= 0; i-- )); do
      prio="${_PACK_WORK[i]##*$'\x1f'}"
      if [[ "${prio}" -gt "${drop_prio}" ]]; then
        drop_prio="${prio}"
        drop_idx="${i}"
      fi
    done

    if [[ "${drop_idx}" -lt 0 ]] || [[ "${drop_prio}" -le 0 ]]; then
      # Only P0 items remain; accept the overflow and let the renderer
      # truncate the trailing line.
      break
    fi

    local new=()
    for (( i = 0; i < ${#_PACK_WORK[@]}; i++ )); do
      [[ "${i}" -ne "${drop_idx}" ]] && new+=("${_PACK_WORK[i]}")
    done
    _PACK_WORK=("${new[@]}")
  done

  _PLAN_LINES=("${_PACK_PLAN[@]}")
  _PLAN_WIDTHS=("${_PACK_PLAN_W[@]}")
}

# layout_pack_once <width>
#
# Greedy left-to-right wrap of _PACK_WORK into _PACK_PLAN respecting
# `width`. Sets _PACK_LINES to the line count and writes per-line
# visible widths into _PACK_PLAN_W.
layout_pack_once() {
  local width="${1}"
  local sep_w="${LAYOUT_SEP_W}"

  _PACK_PLAN=()
  _PACK_PLAN_W=()
  local cur_text=""
  local cur_w=0
  local i rec text w

  for (( i = 0; i < ${#_PACK_WORK[@]}; i++ )); do
    rec="${_PACK_WORK[i]}"
    # Inline parse of the US-delimited record for speed.
    text="${rec#*$'\x1f'}"
    text="${text%%$'\x1f'*}"
    w="${rec%$'\x1f'*}"
    w="${w##*$'\x1f'}"

    if [[ -z "${cur_text}" ]]; then
      cur_text="${text}"
      cur_w="${w}"
    elif [[ $(( cur_w + sep_w + w )) -gt $(( width - 1 )) ]]; then
      _PACK_PLAN+=("${cur_text}")
      _PACK_PLAN_W+=("${cur_w}")
      cur_text="${text}"
      cur_w="${w}"
    else
      cur_text="${cur_text}${LAYOUT_SEP}${text}"
      cur_w=$(( cur_w + sep_w + w ))
    fi
  done

  if [[ -n "${cur_text}" ]]; then
    _PACK_PLAN+=("${cur_text}")
    _PACK_PLAN_W+=("${cur_w}")
  fi

  _PACK_LINES="${#_PACK_PLAN[@]}"
}

# layout_render <width>
#
# Print _PLAN_LINES, one per line, ANSI-aware truncating any line whose
# pre-computed visible width exceeds `width`. Truncation strips ANSI on
# the offending line (acceptable on an over-narrow tty) and appends "…".
layout_render() {
  local width="${1}"
  local i line vis_w stripped
  for (( i = 0; i < ${#_PLAN_LINES[@]}; i++ )); do
    line="${_PLAN_LINES[i]}"
    vis_w="${_PLAN_WIDTHS[i]}"
    if [[ "${vis_w}" -le "${width}" ]]; then
      printf "%b\n" "${line}"
    else
      stripped=$(printf "%b" "${line}" | sed 's/\x1b\[[0-9;]*m//g')
      printf "%s…\n" "${stripped:0:$(( width - 1 ))}"
    fi
  done
}
