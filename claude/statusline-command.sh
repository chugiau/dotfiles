#!/usr/bin/env bash
# Claude Code statusline script

# Ensure common tool paths are available
export PATH="/usr/local/bin:/usr/bin:/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:$PATH"

input=$(cat)

# Guard: jq is required
if ! command -v jq >/dev/null 2>&1; then
  echo "claude statusline: jq not found in PATH"
  exit 0
fi

# --- Extract fields from JSON ---
model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
version=$(echo "$input" | jq -r '.version // ""')

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
cur_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty')
cur_output=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // empty')
cur_cache_write=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cur_cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
session_id=$(echo "$input" | jq -r '.session_id // ""')

# --- ANSI colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'
DIM='\033[2m'
BOLD='\033[1m'

# --- Git branch and status counters ---
git_branch=""
git_staged=0
git_modified=0
git_untracked=0
git_added=0
git_deleted=0
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$git_branch" ]; then
    while IFS= read -r line; do
      xy="${line:0:2}"
      x="${xy:0:1}"
      y="${xy:1:1}"
      case "$x" in
        A|M|D|R|C) git_staged=$(( git_staged + 1 )) ;;
      esac
      case "$y" in
        M|D) git_modified=$(( git_modified + 1 )) ;;
      esac
      if [ "$xy" = "??" ]; then
        git_untracked=$(( git_untracked + 1 ))
      fi
    done < <(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
    if [ "$git_staged" -gt 0 ] || [ "$git_modified" -gt 0 ]; then
      while IFS=$'\t' read -r added deleted _rest; do
        [[ "$added" =~ ^[0-9]+$ ]]  && git_added=$(( git_added + added ))
        [[ "$deleted" =~ ^[0-9]+$ ]] && git_deleted=$(( git_deleted + deleted ))
      done < <(git -C "$cwd" --no-optional-locks diff --numstat 2>/dev/null; git -C "$cwd" --no-optional-locks diff --cached --numstat 2>/dev/null)
    fi
  fi
fi

# --- Project folder name ---
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // ""')
folder_name=$(basename "$project_dir")

# --- Session duration (minutes since transcript file was created) ---
session_mins=0
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  file_mtime=$(stat -c %Y "$transcript_path" 2>/dev/null || stat -f %m "$transcript_path" 2>/dev/null)
  now=$(date +%s)
  if [ -n "$file_mtime" ]; then
    elapsed=$(( (now - file_mtime) / 60 ))
    session_mins=$elapsed
  fi
fi

# --- Token count ---
total_tokens=$(( total_input + total_output ))

# --- Progress bar function ---
# Usage: make_bar <percentage> <width>
# Foreground (filled): Block Unicode █ ▉ ▊ ▋ ▌ ▍ ▎ ▏
# Background (empty):  Shade Unicode ░
make_bar() {
  local pct=${1:-0}
  local width=${2:-10}
  local filled=$(( (pct * width + 50) / 100 ))
  [ $filled -gt $width ] && filled=$width
  local empty=$(( width - filled ))
  local bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty); do bar="${bar}░"; done
  printf "%s" "$bar"
}

# --- Compact token notation function ---
# Usage: compact_tokens <number>
# Returns: e.g. 170234 -> 170.2k, 1234567 -> 1.2m, 999 -> 999
compact_tokens() {
  local n=${1:-0}
  if [ "$n" -ge 1000000 ]; then
    printf "%.1fm" "$(echo "scale=1; $n / 1000000" | bc)"
  elif [ "$n" -ge 1000 ]; then
    printf "%.1fk" "$(echo "scale=1; $n / 1000" | bc)"
  else
    printf "%s" "$n"
  fi
}

# --- Context bar ---
ctx_pct=0
[ -n "$used_pct" ] && ctx_pct=$(printf "%.0f" "$used_pct")
ctx_bar=$(make_bar "$ctx_pct" 10)

# --- Rate limit bars and reset times ---
five_bar=""
five_str=""
if [ -n "$five_hour_pct" ]; then
  five_pct=$(printf "%.0f" "$five_hour_pct")
  five_bar=$(make_bar "$five_pct" 10)
  if [ -n "$five_hour_reset" ]; then
    now=$(date +%s)
    secs_left=$(( five_hour_reset - now ))
    if [ $secs_left -gt 0 ]; then
      h=$(( secs_left / 3600 ))
      m=$(( (secs_left % 3600) / 60 ))
      five_str="(resets in ${h}h ${m}m)"
    else
      five_str="(resetting)"
    fi
  fi
fi

seven_bar=""
seven_str=""
if [ -n "$seven_day_pct" ]; then
  seven_pct=$(printf "%.0f" "$seven_day_pct")
  seven_bar=$(make_bar "$seven_pct" 10)
  if [ -n "$seven_day_reset" ]; then
    now=$(date +%s)
    secs_left=$(( seven_day_reset - now ))
    if [ $secs_left -gt 0 ]; then
      d=$(( secs_left / 86400 ))
      h=$(( (secs_left % 86400) / 3600 ))
      seven_str="(resets in ${d}d ${h}h)"
    else
      seven_str="(resetting)"
    fi
  fi
fi

# --- CLAUDE.md count ---
claude_md_count=0
if [ -n "$project_dir" ] && [ -d "$project_dir" ]; then
  claude_md_count=$(find "$project_dir" -maxdepth 5 -name "CLAUDE.md" 2>/dev/null | wc -l | tr -d ' ')
fi

# --- Hooks count ---
hooks_count=0
hooks_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks"
if [ -d "$hooks_dir" ]; then
  hooks_count=$(find "$hooks_dir" -maxdepth 3 \( -name "*.sh" -o -name "*.js" -o -name "*.ts" -o -name "*.py" \) 2>/dev/null | wc -l | tr -d ' ')
fi

# Also count hooks defined in settings.json
settings_hooks=$(jq -r '
  .hooks // {} |
  to_entries |
  map(.value | map(.hooks // []) | flatten) |
  flatten |
  length
' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" 2>/dev/null || echo 0)
[ -n "$settings_hooks" ] && hooks_count=$settings_hooks

# --- Active sub-agents ---
subagent_count=0
if [ -n "$session_id" ] && echo "$session_id" | grep -qE '^[a-zA-Z0-9_-]+$'; then
  counter_file="/tmp/claude-subagents-${session_id}"
  if [ -f "$counter_file" ]; then
    subagent_count=$(cat "$counter_file" 2>/dev/null || echo 0)
    # Ensure it's a non-negative integer
    [[ "$subagent_count" =~ ^[0-9]+$ ]] || subagent_count=0
  fi
fi

# --- Active task time from cost.total_duration_ms ---
total_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
active_secs=0
active_time_str=""
if [ -n "$total_duration_ms" ] && [[ "$total_duration_ms" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  active_secs=$(( ${total_duration_ms%%.*} / 1000 ))
fi

if [ "$active_secs" -gt 0 ]; then
  at_h=$(( active_secs / 3600 ))
  at_m=$(( (active_secs % 3600) / 60 ))
  if [ "$at_h" -gt 0 ]; then
    active_time_str="${at_h}h ${at_m}m"
  else
    active_time_str="${at_m}m"
  fi
fi

# --- Cost from JSON input ---
cost=""
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$total_cost" ] && [ "$total_cost" != "null" ] && [ "$total_cost" != "0" ]; then
  cost=$(printf "\$%.4f" "$total_cost")
fi

# --- Line 1 ---
line1=""
# Model
line1="${line1}🧠 ${BOLD}[${model_name}]${RESET}"
line1="${line1} | "
# Folder + git branch
line1="${line1}📁 ${YELLOW}${folder_name}${RESET}"
if [ -n "$git_branch" ]; then
  line1="${line1} 🌿 git:(${MAGENTA}${git_branch}${RESET})"
fi
# Git status counters (only shown when there are changes)
git_status_str=""
[ "$git_staged" -gt 0 ]   && git_status_str="${git_status_str} ${GREEN}+${git_staged}${RESET}"
[ "$git_modified" -gt 0 ] && git_status_str="${git_status_str} ${YELLOW}~${git_modified}${RESET}"
[ "$git_untracked" -gt 0 ] && git_status_str="${git_status_str} ${DIM}?${git_untracked}${RESET}"
# Added/deleted line counts
if [ "$git_added" -gt 0 ] || [ "$git_deleted" -gt 0 ]; then
  git_status_str="${git_status_str} ${GREEN}+${git_added}${RESET}/${RED}-${git_deleted}${RESET} lines"
fi
[ -n "$git_status_str" ] && line1="${line1}${git_status_str}"
line1="${line1} | "
# Session time (total elapsed) + active task time + tokens
line1="${line1}⏱ ${session_mins}m"
if [ -n "$active_time_str" ]; then
  line1="${line1} (active: ${CYAN}${active_time_str}${RESET})"
fi
line1="${line1} · ${total_tokens} tokens"
# Sub-agents
if [ "$subagent_count" -gt 0 ] 2>/dev/null; then
  line1="${line1} | ${CYAN}🤖 ${subagent_count} sub-agent$([ "$subagent_count" -gt 1 ] && echo s)${RESET}"
fi

# --- Line 2 ---
line2=""
# Context
line2="${line2}🗃️ Context ${GREEN}${ctx_bar}${RESET} ${GREEN}${ctx_pct}%${RESET}"
# Usage (5-hour)
if [ -n "$five_hour_pct" ]; then
  line2="${line2} | 🕔 Usage ${GREEN}${five_bar}${RESET} ${GREEN}${five_pct}%${RESET}"
  [ -n "$five_str" ] && line2="${line2} ${five_str}"
fi
# Weekly (7-day)
if [ -n "$seven_day_pct" ]; then
  line2="${line2} | 📅 Weekly ${GREEN}${seven_bar}${RESET} ${GREEN}${seven_pct}%${RESET}"
  [ -n "$seven_str" ] && line2="${line2} ${seven_str}"
fi
# Version
[ -n "$version" ] && line2="${line2} · current: ${version}"

# --- Cache hit rate and current call token stats ---
cache_stats=""
if [ -n "$cur_input" ]; then
  total_for_cache=$(( cur_input + cur_cache_write + cur_cache_read ))

  if [ "$total_for_cache" -gt 0 ]; then
    cache_hit_pct=$(( (cur_cache_read * 100) / total_for_cache ))
  else
    cache_hit_pct=0
  fi
  # Color: red if below 80%, green if >= 80%
  if [ "$cache_hit_pct" -ge 80 ]; then
    cache_color="$GREEN"
  else
    cache_color="$RED"
  fi
  cur_input_fmt=$(compact_tokens "$cur_input")
  cur_output_fmt=$(compact_tokens "$cur_output")
  cache_stats="cache: ${cache_color}${cache_hit_pct}%${RESET} | in: ${cur_input_fmt} out: ${cur_output_fmt}"
fi

# --- Line 3 ---
line3=""
line3="${line3}${claude_md_count} CLAUDE.md | 🪝 ${hooks_count} hooks"
[ -n "$cache_stats" ] && line3="${line3} | ${cache_stats}"
[ -n "$cost" ] && line3="${line3} | 💰 ${cost}"

# --- Output ---
printf '%b\n%b\n%b\n%b\n' "$line1" "$line2" "$line3" "$line4"
