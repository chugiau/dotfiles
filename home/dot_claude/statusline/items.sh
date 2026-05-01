#!/usr/bin/env bash
# statusline/items.sh — display-item emitters and the canonical order.
#
# Each emit_<id> function is a no-op when the item isn't applicable, or
# pushes one record into the global _ITEMS array via item_push. Records
# are encoded as
#     <id>\x1f<text>\x1f<visible_width>\x1f<priority>
# (US-delimited) so we can stay on bash 3.2 without associative arrays.
# `text` carries ANSI escapes; `visible_width` is the terminal-column
# count *excluding* ANSI escapes and is computed by the emitter (cheaper
# and more accurate than measuring constructed strings whose width is
# distorted by emoji and CJK glyphs).
#
# Priorities:
#   0 — always rendered; truncated rather than dropped.
#   1 — important (folder, branch, total tokens, ctx percent).
#   2 — useful  (cost, version, rate-limit bars, ahead/behind, git
#                staged/modified counts).
#   3 — nice-to-have (untracked count, line-stat diff, cache-hit pct,
#                in/out current-call tokens, CLAUDE.md count, hook
#                count, sub-agent badge, ⚡ active / ⏱ api / 🕐 session).
#
# Drops are the layout module's job; emitters never reorder.

_ITEMS=()

# item_push <id> <text> <visible_width> <priority>
item_push() {
  local id="${1}"
  local text="${2}"
  local width="${3}"
  local prio="${4}"
  _ITEMS+=("${id}"$'\x1f'"${text}"$'\x1f'"${width}"$'\x1f'"${prio}")
}

# Record-field accessors (used by layout.sh).
item_id() {
  local r="${1}"
  printf "%s" "${r%%$'\x1f'*}"
}

item_text() {
  local r="${1}"
  r="${r#*$'\x1f'}"
  printf "%s" "${r%%$'\x1f'*}"
}

item_width() {
  local r="${1}"
  r="${r#*$'\x1f'}"
  r="${r#*$'\x1f'}"
  printf "%s" "${r%%$'\x1f'*}"
}

item_priority() {
  local r="${1}"
  printf "%s" "${r##*$'\x1f'}"
}

# ── Emitters ───────────────────────────────────────────────────────────────
# Visible widths assume single-cell emoji render as 2 columns and ASCII as 1.

# 🧠 [<model>]
emit_model() {
  local label="🧠 ${BOLD}[${model_name}]${RESET}"
  local w=$(( 2 + 1 + 1 + ${#model_name} + 1 ))
  item_push "model" "${label}" "${w}" 0
}

# 📁 <folder>  (in worktree mode the folder is the project-root parent)
emit_folder() {
  local name
  if [[ -n "${git_worktree}" ]]; then
    name=$(basename "$(dirname "${project_dir}")")
    [[ -z "${name}" || "${name}" == "." ]] && name=$(basename "${project_dir}")
  else
    name=$(basename "${project_dir}")
  fi
  [[ -z "${name}" ]] && return
  local label="📁 ${YELLOW}${name}${RESET}"
  local w=$(( 2 + 1 + ${#name} ))
  item_push "folder" "${label}" "${w}" 1
}

# 🪵 <worktree>
emit_worktree() {
  [[ -z "${git_worktree}" ]] && return
  local short
  short=$(truncate_name "${git_worktree}" 28)
  local label="🪵 ${CYAN}${short}${RESET}"
  local w=$(( 2 + 1 + ${#short} ))
  item_push "worktree" "${label}" "${w}" 1
}

# 🌿 git:(<branch>) — suppressed when redundant with the worktree slug.
emit_branch() {
  [[ -z "${git_branch}" ]] && return
  local branch_redundant=0
  if [[ -n "${git_worktree}" ]]; then
    if [[ "${git_branch}" == "${git_worktree}" ]] \
       || [[ "${git_branch}" == "worktree-${git_worktree}" ]] \
       || [[ "${git_branch}" == *"${git_worktree}"* ]]; then
      branch_redundant=1
    fi
  fi
  [[ "${branch_redundant}" -eq 1 ]] && return

  local short
  if [[ -n "${git_worktree}" ]]; then
    short=$(truncate_name "${git_branch}" 28)
  else
    short=$(truncate_name "${git_branch}" 30)
  fi
  local label="🌿 git:(${MAGENTA}${short}${RESET})"
  # 🌿 (2) + " " (1) + "git:(" (5) + branch + ")" (1)
  local w=$(( 2 + 1 + 5 + ${#short} + 1 ))
  item_push "branch" "${label}" "${w}" 1
}

emit_ahead_behind() {
  [[ "${git_ahead}" -le 0 ]] && [[ "${git_behind}" -le 0 ]] && return
  local label="" w=0
  if [[ "${git_ahead}" -gt 0 ]]; then
    label="${GREEN}↑${git_ahead}${RESET}"
    w=$(( 1 + ${#git_ahead} ))
  fi
  if [[ "${git_behind}" -gt 0 ]]; then
    if [[ -n "${label}" ]]; then
      label="${label} ${RED}↓${git_behind}${RESET}"
      w=$(( w + 1 + 1 + ${#git_behind} ))
    else
      label="${RED}↓${git_behind}${RESET}"
      w=$(( 1 + ${#git_behind} ))
    fi
  fi
  item_push "ahead_behind" "${label}" "${w}" 2
}

emit_git_staged() {
  [[ "${git_staged}" -le 0 ]] && return
  local label="${GREEN}+${git_staged}${RESET}"
  local w=$(( 1 + ${#git_staged} ))
  item_push "git_staged" "${label}" "${w}" 2
}

emit_git_modified() {
  [[ "${git_modified}" -le 0 ]] && return
  local label="${YELLOW}~${git_modified}${RESET}"
  local w=$(( 1 + ${#git_modified} ))
  item_push "git_modified" "${label}" "${w}" 2
}

emit_git_untracked() {
  [[ "${git_untracked}" -le 0 ]] && return
  local label="${DIM}?${git_untracked}${RESET}"
  local w=$(( 1 + ${#git_untracked} ))
  item_push "git_untracked" "${label}" "${w}" 3
}

emit_git_lines() {
  [[ "${git_added}" -le 0 ]] && [[ "${git_deleted}" -le 0 ]] && return
  local label="${GREEN}+${git_added}${RESET}/${RED}-${git_deleted}${RESET} lines"
  # "+" + N + "/" + "-" + N + " lines" (6)
  local w=$(( 1 + ${#git_added} + 1 + 1 + ${#git_deleted} + 6 ))
  item_push "git_lines" "${label}" "${w}" 3
}

emit_total_tokens() {
  local total=$(( total_input + total_output ))
  local s="${total} tokens"
  item_push "total_tokens" "${s}" "${#s}" 1
}

emit_subagents() {
  [[ "${subagent_count}" -le 0 ]] && return
  local lab="sub-agent"
  [[ "${subagent_count}" -gt 1 ]] && lab="sub-agents"
  local label="${CYAN}🤖 ${subagent_count} ${lab}${RESET}"
  # 🤖 (2) + " " + count + " " + lab
  local w=$(( 2 + 1 + ${#subagent_count} + 1 + ${#lab} ))
  item_push "subagents" "${label}" "${w}" 3
}

# 🗃️ Context ██████░░░░
emit_ctx_bar() {
  local color bar
  color=$(pct_color "${ctx_pct}")
  bar=$(make_bar "${ctx_pct}" 10)
  local label="🗃️ Context ${color}${bar}${RESET}"
  # 🗃️ (2) + " Context " (9) + bar (10)
  local w=$(( 2 + 9 + 10 ))
  item_push "ctx_bar" "${label}" "${w}" 0
}

emit_ctx_pct() {
  [[ -z "${used_pct}" ]] && return
  local color s
  color=$(pct_color "${ctx_pct}")
  s="${ctx_pct}%"
  local label="${color}${s}${RESET}"
  item_push "ctx_pct" "${label}" "${#s}" 1
}

# 🕔 Usage ██████░░░░ NN% (resets in Hh Mm)
emit_five_hour() {
  [[ -z "${five_hour_pct}" ]] && return
  local pct bar reset_str color
  pct=$(printf "%.0f" "${five_hour_pct}")
  bar=$(make_bar "${pct}" 10)
  reset_str=$(format_reset_countdown "${five_hour_reset}" "hm")
  color=$(pct_color "${pct}")
  local label="🕔 Usage ${color}${bar}${RESET} ${color}${pct}%${RESET}"
  # 🕔 (2) + " Usage " (7) + bar (10) + " " (1) + pct + "%" (1)
  local w=$(( 2 + 7 + 10 + 1 + ${#pct} + 1 ))
  if [[ -n "${reset_str}" ]]; then
    label="${label} ${reset_str}"
    w=$(( w + 1 + ${#reset_str} ))
  fi
  item_push "five_hour" "${label}" "${w}" 2
}

# 📅 Weekly ██████░░░░ NN% (resets in Dd Hh)
emit_seven_day() {
  [[ -z "${seven_day_pct}" ]] && return
  local pct bar reset_str color
  pct=$(printf "%.0f" "${seven_day_pct}")
  bar=$(make_bar "${pct}" 10)
  reset_str=$(format_reset_countdown "${seven_day_reset}" "dh")
  color=$(pct_color "${pct}")
  local label="📅 Weekly ${color}${bar}${RESET} ${color}${pct}%${RESET}"
  # 📅 (2) + " Weekly " (8) + bar (10) + " " (1) + pct + "%" (1)
  local w=$(( 2 + 8 + 10 + 1 + ${#pct} + 1 ))
  if [[ -n "${reset_str}" ]]; then
    label="${label} ${reset_str}"
    w=$(( w + 1 + ${#reset_str} ))
  fi
  item_push "seven_day" "${label}" "${w}" 2
}

emit_version() {
  [[ -z "${version}" ]] && return
  local s="current: ${version}"
  item_push "version" "${s}" "${#s}" 2
}

emit_claude_md() {
  local s="${claude_md_count} CLAUDE.md"
  item_push "claude_md" "${s}" "${#s}" 3
}

emit_hooks() {
  local label="🪝 ${hooks_count} hooks"
  local w=$(( 2 + 1 + ${#hooks_count} + 6 ))
  item_push "hooks" "${label}" "${w}" 3
}

emit_cache_pct() {
  [[ -z "${cur_input}" ]] && return
  local total_for_cache hit_pct color label
  total_for_cache=$(( cur_input + cur_cache_write + cur_cache_read ))
  hit_pct=0
  [[ "${total_for_cache}" -gt 0 ]] && hit_pct=$(( (cur_cache_read * 100) / total_for_cache ))
  color=$(cache_pct_color "${hit_pct}")
  label="cache: ${color}${hit_pct}%${RESET}"
  # "cache: " (7) + pct + "%" (1)
  local w=$(( 7 + ${#hit_pct} + 1 ))
  item_push "cache_pct" "${label}" "${w}" 3
}

emit_in_out() {
  [[ -z "${cur_input}" ]] && return
  local in_fmt out_fmt s
  in_fmt=$(compact_tokens "${cur_input}")
  out_fmt=$(compact_tokens "${cur_output}")
  s="in: ${in_fmt} out: ${out_fmt}"
  item_push "in_out" "${s}" "${#s}" 3
}

emit_cost() {
  [[ -z "${cost}" ]] && return
  local label="💰 ${cost}"
  local w=$(( 2 + 1 + ${#cost} ))
  item_push "cost" "${label}" "${w}" 2
}

emit_active_time() {
  [[ -z "${active_time_str}" ]] && return
  local label="⚡ ${active_time_str}"
  local w=$(( 2 + 1 + ${#active_time_str} ))
  item_push "active_time" "${label}" "${w}" 3
}

emit_api_duration() {
  [[ -z "${api_duration_str}" ]] && return
  local label="⏱ ${api_duration_str}"
  local w=$(( 2 + 1 + ${#api_duration_str} ))
  item_push "api_duration" "${label}" "${w}" 3
}

emit_session_mins() {
  [[ -z "${session_mins}" ]] || [[ "${session_mins}" -le 0 ]] && return
  local label="🕐 ${session_mins}m"
  local w=$(( 2 + 1 + ${#session_mins} + 1 ))
  item_push "session_mins" "${label}" "${w}" 3
}

# ✦ effort:<level> — colour-coded reasoning-effort setting.
emit_effort() {
  [[ -z "${effort_level}" ]] && return
  local color
  case "${effort_level}" in
    low)          color="${GREEN}"   ;;
    medium)       color="${YELLOW}"  ;;
    high)         color="${ORANGE}"  ;;
    xhigh|max)    color="${RED}"     ;;
    *)            color="${RESET}"   ;;
  esac
  local label="✦ effort:${color}${effort_level}${RESET}"
  # ✦ (2) + " effort:" (8) + level
  local w=$(( 2 + 8 + ${#effort_level} ))
  item_push "effort" "${label}" "${w}" 2
}

# ✎ <output_style_name> — active output style, suppressed for "default".
emit_output_style() {
  [[ -z "${output_style_name}" ]] && return
  [[ "$(printf '%s' "${output_style_name}" | tr '[:upper:]' '[:lower:]')" == "default" ]] && return
  local label="✎ ${output_style_name}"
  # ✎ (2) + " " (1) + name
  local w=$(( 2 + 1 + ${#output_style_name} ))
  item_push "output_style" "${label}" "${w}" 3
}

# 💭 thinking — shown only when extended thinking is enabled.
emit_thinking() {
  [[ "${thinking_enabled}" != "true" ]] && return
  local label="💭 thinking"
  # 💭 (2) + " thinking" (9)
  local w=$(( 2 + 9 ))
  item_push "thinking" "${label}" "${w}" 3
}

# VIM:<mode> — vim-editor mode badge; bold + colour by mode.
emit_vim_mode() {
  [[ -z "${vim_mode}" ]] && return
  local color
  case "${vim_mode}" in
    INSERT)              color="${GREEN}"   ;;
    NORMAL)              color="${YELLOW}"  ;;
    VISUAL|VISUAL\ LINE) color="${MAGENTA}" ;;
    *)                   color="${RESET}"   ;;
  esac
  local label="${BOLD}${color}VIM:${vim_mode}${RESET}"
  # "VIM:" (4) + mode
  local w=$(( 4 + ${#vim_mode} ))
  item_push "vim_mode" "${label}" "${w}" 1
}

# emit_all — invoked by the entrypoint after data has been populated.
# Calls every emit_* in canonical left-to-right order. Drops are the
# layout module's job; this list defines the ordering only.
emit_all() {
  emit_model
  emit_vim_mode
  emit_folder
  emit_worktree
  emit_branch
  emit_ahead_behind
  emit_git_staged
  emit_git_modified
  emit_git_untracked
  emit_git_lines
  emit_total_tokens
  emit_subagents
  emit_ctx_bar
  emit_ctx_pct
  emit_five_hour
  emit_seven_day
  emit_version
  emit_effort
  emit_output_style
  emit_thinking
  emit_claude_md
  emit_hooks
  emit_cache_pct
  emit_in_out
  emit_cost
  emit_active_time
  emit_api_duration
  emit_session_mins
}
