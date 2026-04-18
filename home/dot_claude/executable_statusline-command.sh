#!/usr/bin/env bash
#
# statusline-command.sh — Claude Code statusline renderer.
#
# Reads a JSON payload from stdin (provided by Claude Code) and prints a
# multi-line statusline with model info, git state, context/rate-limit bars,
# token stats, cache metrics, cost, and timing info.
#
# Compatibility: bash 3.2+, macOS and Linux (POSIX-safe where possible).

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly _PATH_EXTRA="/usr/local/bin:/usr/bin:/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin"

# ANSI color codes
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly ORANGE='\033[0;33m'
readonly YELLOW='\033[1;33m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly RESET='\033[0m'
readonly DIM='\033[2m'
readonly BOLD='\033[1m'

# ---------------------------------------------------------------------------
# Helper: make_bar
# ---------------------------------------------------------------------------
# Renders a Unicode block progress bar.
#
# Arguments:
#   $1 - percentage (integer 0–100)
#   $2 - bar width in characters (default: 10)
#
# Output (stdout): filled █ characters followed by empty ░ characters.
#######################################
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

# ---------------------------------------------------------------------------
# Helper: compact_tokens
# ---------------------------------------------------------------------------
# Formats a large integer into a compact human-readable notation.
#
# Arguments:
#   $1 - integer token count
#
# Output (stdout): e.g. 170234 → 170.2k, 1234567 → 1.2m, 999 → 999
#######################################
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

# ---------------------------------------------------------------------------
# Helper: file_mtime
# ---------------------------------------------------------------------------
# Returns the modification time of a file as Unix epoch seconds.
# Works on both Linux (stat -c) and macOS/BSD (stat -f).
#
# Arguments:
#   $1 - absolute path to the file
#
# Output (stdout): epoch integer, or empty string on failure.
#######################################
file_mtime() {
  local path="${1}"
  stat -c %Y "${path}" 2>/dev/null || stat -f %m "${path}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# extract_fields <input_json>
# ---------------------------------------------------------------------------
# Parses the JSON payload into global variables.
#
# Arguments:
#   $1 - raw JSON string from stdin
#######################################
extract_fields() {
  local input="${1}"

  model_name=$(echo "${input}" | jq -r '.model.display_name // "Unknown"')
  cwd=$(echo "${input}"        | jq -r '.workspace.current_dir // .cwd // ""')
  version=$(echo "${input}"    | jq -r '.version // ""')
  project_dir=$(echo "${input}" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // ""')
  transcript_path=$(echo "${input}" | jq -r '.transcript_path // ""')
  session_id=$(echo "${input}" | jq -r '.session_id // ""')
  git_worktree=$(echo "${input}" | jq -r '.workspace.git_worktree // ""')

  used_pct=$(echo "${input}"       | jq -r '.context_window.used_percentage // empty')
  total_input=$(echo "${input}"    | jq -r '.context_window.total_input_tokens // 0')
  total_output=$(echo "${input}"   | jq -r '.context_window.total_output_tokens // 0')
  cur_input=$(echo "${input}"      | jq -r '.context_window.current_usage.input_tokens // empty')
  cur_output=$(echo "${input}"     | jq -r '.context_window.current_usage.output_tokens // empty')
  cur_cache_write=$(echo "${input}" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
  cur_cache_read=$(echo "${input}" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

  five_hour_pct=$(echo "${input}"   | jq -r '.rate_limits.five_hour.used_percentage // empty')
  five_hour_reset=$(echo "${input}" | jq -r '.rate_limits.five_hour.resets_at // empty')
  seven_day_pct=$(echo "${input}"   | jq -r '.rate_limits.seven_day.used_percentage // empty')
  seven_day_reset=$(echo "${input}" | jq -r '.rate_limits.seven_day.resets_at // empty')

  total_duration_ms=$(echo "${input}" | jq -r '.cost.total_duration_ms // empty')
  total_cost=$(echo "${input}"        | jq -r '.cost.total_cost_usd // empty')
}

# ---------------------------------------------------------------------------
# collect_git_info <directory>
# ---------------------------------------------------------------------------
# Populates git_branch, git_staged, git_modified, git_untracked,
# git_added, and git_deleted for the given working directory.
#
# Arguments:
#   $1 - absolute path to the working directory
#######################################
collect_git_info() {
  local dir="${1}"

  git_branch=""
  git_staged=0
  git_modified=0
  git_untracked=0
  git_added=0
  git_deleted=0

  if [[ -z "${dir}" ]] || ! command -v git >/dev/null 2>&1; then
    return
  fi

  git_branch=$(git -C "${dir}" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
    || git -C "${dir}" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

  if [[ -z "${git_branch}" ]]; then
    return
  fi

  local line xy x y
  while IFS= read -r line; do
    xy="${line:0:2}"
    x="${xy:0:1}"
    y="${xy:1:1}"
    case "${x}" in
      A|M|D|R|C) git_staged=$(( git_staged + 1 )) ;;
    esac
    case "${y}" in
      M|D) git_modified=$(( git_modified + 1 )) ;;
    esac
    [[ "${xy}" == "??" ]] && git_untracked=$(( git_untracked + 1 ))
  done < <(git -C "${dir}" --no-optional-locks status --porcelain 2>/dev/null)

  if [[ "${git_staged}" -gt 0 ]] || [[ "${git_modified}" -gt 0 ]]; then
    local added deleted _rest
    while IFS=$'\t' read -r added deleted _rest; do
      [[ "${added}"   =~ ^[0-9]+$ ]] && git_added=$(( git_added + added ))
      [[ "${deleted}" =~ ^[0-9]+$ ]] && git_deleted=$(( git_deleted + deleted ))
    done < <(
      git -C "${dir}" --no-optional-locks diff --numstat 2>/dev/null
      git -C "${dir}" --no-optional-locks diff --cached --numstat 2>/dev/null
    )
  fi
}

# ---------------------------------------------------------------------------
# compute_session_mins <transcript_path>
# ---------------------------------------------------------------------------
# Outputs the number of whole minutes elapsed since the transcript file was
# last modified, or 0 if the file is absent or its mtime cannot be read.
#
# Arguments:
#   $1 - path to the transcript file
#######################################
compute_session_mins() {
  local path="${1}"
  local session_mins=0

  if [[ -n "${path}" ]] && [[ -f "${path}" ]]; then
    local file_mtime_val now elapsed
    file_mtime_val=$(file_mtime "${path}")
    now=$(date +%s)
    if [[ -n "${file_mtime_val}" ]]; then
      elapsed=$(( (now - file_mtime_val) / 60 ))
      session_mins="${elapsed}"
    fi
  fi

  printf "%s" "${session_mins}"
}

# ---------------------------------------------------------------------------
# format_active_time <total_duration_ms>
# ---------------------------------------------------------------------------
# Converts a duration in milliseconds to a human-readable string like
# "5m" or "1h 12m". Outputs an empty string for durations of 0.
#
# Arguments:
#   $1 - duration in milliseconds (may be a decimal, e.g. "3723456.7")
#######################################
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

# ---------------------------------------------------------------------------
# format_reset_countdown <epoch_seconds> <unit>
# ---------------------------------------------------------------------------
# Formats a "resets in …" countdown string for a rate-limit window.
#
# Arguments:
#   $1 - Unix epoch at which the window resets
#   $2 - granularity: "hm" (hours+minutes) or "dh" (days+hours)
#######################################
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

# ---------------------------------------------------------------------------
# count_claude_md <project_dir>
# ---------------------------------------------------------------------------
# Counts CLAUDE.md files within up to 5 directory levels of project_dir.
#
# Arguments:
#   $1 - project root directory
#######################################
count_claude_md() {
  local dir="${1}"
  if [[ -n "${dir}" ]] && [[ -d "${dir}" ]]; then
    find "${dir}" -maxdepth 5 -name "CLAUDE.md" 2>/dev/null | wc -l | tr -d ' '
  else
    printf "0"
  fi
}

# ---------------------------------------------------------------------------
# count_hooks
# ---------------------------------------------------------------------------
# Returns the number of hooks defined in settings.json (preferred) or,
# as a fallback, hook script files found under the hooks directory.
#######################################
count_hooks() {
  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local hooks_dir="${claude_dir}/hooks"
  local settings_file="${claude_dir}/settings.json"
  local count=0

  # Prefer settings.json hook count when available
  local settings_hooks
  settings_hooks=$(jq -r '
    .hooks // {} |
    to_entries |
    map(.value | map(.hooks // []) | flatten) |
    flatten |
    length
  ' "${settings_file}" 2>/dev/null)

  if [[ -n "${settings_hooks}" ]] && [[ "${settings_hooks}" =~ ^[0-9]+$ ]]; then
    count="${settings_hooks}"
  elif [[ -d "${hooks_dir}" ]]; then
    count=$(find "${hooks_dir}" -maxdepth 3 \
      \( -name "*.sh" -o -name "*.js" -o -name "*.ts" -o -name "*.py" \) \
      2>/dev/null | wc -l | tr -d ' ')
  fi

  printf "%s" "${count}"
}

# ---------------------------------------------------------------------------
# count_subagents <session_id>
# ---------------------------------------------------------------------------
# Reads the sub-agent counter file for the given session, if present.
#
# Arguments:
#   $1 - session ID string
#######################################
count_subagents() {
  local session_id="${1}"
  local subagent_count=0

  if [[ -n "${session_id}" ]] && echo "${session_id}" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    local counter_file="/tmp/claude-subagents-${session_id}"
    if [[ -f "${counter_file}" ]]; then
      local raw
      raw=$(cat "${counter_file}" 2>/dev/null || echo 0)
      [[ "${raw}" =~ ^[0-9]+$ ]] && subagent_count="${raw}"
    fi
  fi

  printf "%s" "${subagent_count}"
}

# ---------------------------------------------------------------------------
# cache_pct_color
# ---------------------------------------------------------------------------
# Returns the ANSI color escape for a cache hit-rate percentage.
# Higher hit rate = better, so the color scale is inverted vs pct_color:
#   [0,  40) → red     (poor cache performance)
#   [40, 80) → orange  (moderate)
#   [80, 90) → yellow  (good)
#   [90,100] → green   (excellent)
#
# Arguments:
#   $1 - integer percentage (0–100)
#######################################
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

# ---------------------------------------------------------------------------
# truncate_name <name> <max_len>
# ---------------------------------------------------------------------------
# Truncates a string to max_len characters, appending "…" if truncated.
#
# Arguments:
#   $1 - string to truncate
#   $2 - maximum visible length (default: 30)
#######################################
truncate_name() {
  local name="${1}"
  local max="${2:-30}"
  if [[ "${#name}" -gt "${max}" ]]; then
    printf "%s" "${name:0:${max}}…"
  else
    printf "%s" "${name}"
  fi
}

# ---------------------------------------------------------------------------
# build_line1
# ---------------------------------------------------------------------------
# Assembles and prints line 1:
#   model | folder [worktree] [git branch] [git status] | tokens [sub-agents]
#
# Worktree dedup logic:
#   When git_worktree is set, the folder name (basename of project_dir) is
#   typically identical to the worktree slug — showing both is redundant.
#   Instead we show only 📁 <project-root-basename> (the parent dir of the
#   worktree) when available, and skip the folder segment entirely when that
#   is also redundant.  Long worktree and branch names are truncated.
#   If git_branch contains git_worktree as a substring (e.g. the branch is
#   "worktree-<slug>"), the branch display is suppressed to avoid tripling
#   the same slug on one line.
#######################################
build_line1() {
  local total_tokens="${1}"
  local subagent_count="${2}"

  local line=""

  # Model
  line="${line}🧠 ${BOLD}[${model_name}]${RESET}"
  line="${line} | "

  # Folder + git worktree + git branch
  if [[ -n "${git_worktree}" ]]; then
    # In a worktree session: show the project root name (parent of the
    # worktree dir) so the reader knows which repo this belongs to, then
    # show a truncated worktree label.  Skip the branch when it redundantly
    # encodes the same worktree slug.
    local project_root_name wt_short branch_redundant
    project_root_name=$(basename "$(dirname "${project_dir}")")
    # If dirname is "." or "/" the fallback is the project_dir basename itself
    [[ -z "${project_root_name}" || "${project_root_name}" == "." ]] \
      && project_root_name=$(basename "${project_dir}")
    wt_short=$(truncate_name "${git_worktree}" 28)

    line="${line}📁 ${YELLOW}${project_root_name}${RESET}"
    line="${line} 🪵 ${CYAN}${wt_short}${RESET}"

    # Suppress branch when it is just "worktree-<slug>" or equals the slug
    branch_redundant=0
    if [[ -n "${git_branch}" ]]; then
      if [[ "${git_branch}" == "${git_worktree}" ]] \
         || [[ "${git_branch}" == "worktree-${git_worktree}" ]] \
         || [[ "${git_branch}" == *"${git_worktree}"* ]]; then
        branch_redundant=1
      fi
    fi

    if [[ "${branch_redundant}" -eq 0 ]] && [[ -n "${git_branch}" ]]; then
      local branch_short
      branch_short=$(truncate_name "${git_branch}" 28)
      line="${line} 🌿 git:(${MAGENTA}${branch_short}${RESET})"
    fi
  else
    # Normal (non-worktree) session
    local folder_name
    folder_name=$(basename "${project_dir}")
    line="${line}📁 ${YELLOW}${folder_name}${RESET}"
    if [[ -n "${git_branch}" ]]; then
      local branch_short
      branch_short=$(truncate_name "${git_branch}" 30)
      line="${line} 🌿 git:(${MAGENTA}${branch_short}${RESET})"
    fi
  fi

  # Git status counters
  local git_status_str=""
  [[ "${git_staged}"    -gt 0 ]] && git_status_str="${git_status_str} ${GREEN}+${git_staged}${RESET}"
  [[ "${git_modified}"  -gt 0 ]] && git_status_str="${git_status_str} ${YELLOW}~${git_modified}${RESET}"
  [[ "${git_untracked}" -gt 0 ]] && git_status_str="${git_status_str} ${DIM}?${git_untracked}${RESET}"
  if [[ "${git_added}" -gt 0 ]] || [[ "${git_deleted}" -gt 0 ]]; then
    git_status_str="${git_status_str} ${GREEN}+${git_added}${RESET}/${RED}-${git_deleted}${RESET} lines"
  fi
  [[ -n "${git_status_str}" ]] && line="${line}${git_status_str}"

  line="${line} | "

  # Tokens
  line="${line}${total_tokens} tokens"

  # Sub-agents
  if [[ "${subagent_count}" -gt 0 ]] 2>/dev/null; then
    local label="sub-agent"
    [[ "${subagent_count}" -gt 1 ]] && label="sub-agents"
    line="${line} | ${CYAN}🤖 ${subagent_count} ${label}${RESET}"
  fi

  printf "%b" "${line}"
}

# ---------------------------------------------------------------------------
# pct_color
# ---------------------------------------------------------------------------
# Returns the ANSI color escape for a given usage percentage.
# Thresholds (used / consumed perspective — higher pct = more used = worse):
#   [0,  40) → green   (plenty remaining)
#   [40, 80) → orange  (moderate usage)
#   [80, 90) → yellow  (high usage)
#   [90,100] → red     (critical)
#
# Arguments:
#   $1 - integer percentage (0–100)
#######################################
pct_color() {
  local pct="${1:-0}"
  if [[ "${pct}" -ge 90 ]]; then
    printf "%s" "${RED}"
  elif [[ "${pct}" -ge 80 ]]; then
    printf "%s" "${YELLOW}"
  elif [[ "${pct}" -ge 40 ]]; then
    printf "%s" "${ORANGE}"
  else
    printf "%s" "${GREEN}"
  fi
}

# ---------------------------------------------------------------------------
# build_line2
# ---------------------------------------------------------------------------
# Assembles and prints line 2:
#   context bar | [5-hour bar] | [7-day bar] · version
#######################################
build_line2() {
  local ctx_pct="${1}"
  local five_hour_pct="${2}"
  local five_hour_reset="${3}"
  local seven_day_pct="${4}"
  local seven_day_reset="${5}"

  local line=""
  local ctx_bar ctx_color
  ctx_bar=$(make_bar "${ctx_pct}" 10)
  ctx_color=$(pct_color "${ctx_pct}")

  # Context bar
  line="${line}🗃️ Context ${ctx_color}${ctx_bar}${RESET} ${ctx_color}${ctx_pct}%${RESET}"

  # 5-hour rate-limit bar
  if [[ -n "${five_hour_pct}" ]]; then
    local five_pct five_bar five_str five_color
    five_pct=$(printf "%.0f" "${five_hour_pct}")
    five_bar=$(make_bar "${five_pct}" 10)
    five_str=$(format_reset_countdown "${five_hour_reset}" "hm")
    five_color=$(pct_color "${five_pct}")
    line="${line} | 🕔 Usage ${five_color}${five_bar}${RESET} ${five_color}${five_pct}%${RESET}"
    [[ -n "${five_str}" ]] && line="${line} ${five_str}"
  fi

  # 7-day rate-limit bar
  if [[ -n "${seven_day_pct}" ]]; then
    local seven_pct seven_bar seven_str seven_color
    seven_pct=$(printf "%.0f" "${seven_day_pct}")
    seven_bar=$(make_bar "${seven_pct}" 10)
    seven_str=$(format_reset_countdown "${seven_day_reset}" "dh")
    seven_color=$(pct_color "${seven_pct}")
    line="${line} | 📅 Weekly ${seven_color}${seven_bar}${RESET} ${seven_color}${seven_pct}%${RESET}"
    [[ -n "${seven_str}" ]] && line="${line} ${seven_str}"
  fi

  # Version
  [[ -n "${version}" ]] && line="${line} · current: ${version}"

  printf "%b" "${line}"
}

# ---------------------------------------------------------------------------
# build_line3
# ---------------------------------------------------------------------------
# Assembles and prints line 3:
#   CLAUDE.md count | hooks | [cache stats] | [cost] | time info
#
# If the time segment would make the line too long (>120 visible chars),
# it is emitted as a separate line 4 instead.
#
# Arguments:
#   $1 - CLAUDE.md count
#   $2 - hooks count
#   $3 - cost string (may be empty)
#   $4 - active_time_str (time Claude was actively working, e.g. "5m")
#   $5 - session_mins (whole minutes since session start)
#######################################
build_line3() {
  local claude_md_count="${1}"
  local hooks_count="${2}"
  local cost="${3}"
  local active_time_str="${4}"
  local session_mins="${5}"

  local line=""
  line="${line}${claude_md_count} CLAUDE.md | 🪝 ${hooks_count} hooks"

  # Cache hit rate and per-call token stats
  # Color thresholds: [0,40)→red  [40,80)→orange  [80,90)→yellow  [90,100]→green
  if [[ -n "${cur_input}" ]]; then
    local total_for_cache cache_hit_pct cache_color cur_input_fmt cur_output_fmt
    total_for_cache=$(( cur_input + cur_cache_write + cur_cache_read ))
    if [[ "${total_for_cache}" -gt 0 ]]; then
      cache_hit_pct=$(( (cur_cache_read * 100) / total_for_cache ))
    else
      cache_hit_pct=0
    fi
    cache_color=$(cache_pct_color "${cache_hit_pct}")
    cur_input_fmt=$(compact_tokens "${cur_input}")
    cur_output_fmt=$(compact_tokens "${cur_output}")
    line="${line} | cache: ${cache_color}${cache_hit_pct}%${RESET} | in: ${cur_input_fmt} out: ${cur_output_fmt}"
  fi

  [[ -n "${cost}" ]] && line="${line} | 💰 ${cost}"

  # Build timing segment: ⚡ <active_time> | 🕐 <session_mins>m
  local time_seg=""
  if [[ -n "${active_time_str}" ]] || [[ -n "${session_mins}" ]]; then
    local active_part session_part
    active_part=""
    session_part=""
    [[ -n "${active_time_str}" ]] && active_part="⚡ ${active_time_str}"
    [[ -n "${session_mins}" ]]    && session_part="🕐 ${session_mins}m"

    if [[ -n "${active_part}" ]] && [[ -n "${session_part}" ]]; then
      time_seg="${active_part} | ${session_part}"
    elif [[ -n "${active_part}" ]]; then
      time_seg="${active_part}"
    else
      time_seg="${session_part}"
    fi
  fi

  if [[ -n "${time_seg}" ]]; then
    # Strip ANSI escapes to estimate visible length for overflow detection
    local visible_line
    visible_line=$(printf "%b" "${line}" | sed 's/\x1b\[[0-9;]*m//g')
    local time_seg_visible="${time_seg}"  # time_seg has no ANSI codes

    if [[ $(( ${#visible_line} + 3 + ${#time_seg_visible} )) -le 120 ]]; then
      # Fits on line 3
      line="${line} | ${time_seg}"
      printf "%b" "${line}"
    else
      # Overflow to line 4
      printf "%b\n%b" "${line}" "${time_seg}"
    fi
  else
    printf "%b" "${line}"
  fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  export PATH="${_PATH_EXTRA}:${PATH}"

  # Guard: jq is required
  if ! command -v jq >/dev/null 2>&1; then
    printf "claude statusline: jq not found in PATH\n" >&2
    exit 0
  fi

  local input
  input=$(cat)

  # Populate globals from JSON
  extract_fields "${input}"

  # Git info
  collect_git_info "${cwd}"

  # Derived values
  local session_mins active_time_str total_tokens cost
  local ctx_pct subagent_count claude_md_count hooks_count

  session_mins=$(compute_session_mins "${transcript_path}")
  active_time_str=$(format_active_time "${total_duration_ms}")
  total_tokens=$(( total_input + total_output ))

  ctx_pct=0
  [[ -n "${used_pct}" ]] && ctx_pct=$(printf "%.0f" "${used_pct}")

  subagent_count=$(count_subagents "${session_id}")
  claude_md_count=$(count_claude_md "${project_dir}")
  hooks_count=$(count_hooks)

  cost=""
  if [[ -n "${total_cost}" ]] && [[ "${total_cost}" != "null" ]] && [[ "${total_cost}" != "0" ]]; then
    cost=$(printf "\$%.4f" "${total_cost}")
  fi

  # Assemble output lines
  local line1 line2 line3_output
  line1=$(build_line1 "${total_tokens}" "${subagent_count}")
  line2=$(build_line2 "${ctx_pct}" "${five_hour_pct}" "${five_hour_reset}" "${seven_day_pct}" "${seven_day_reset}")
  # build_line3 may emit 1 or 2 lines (the second contains timing info overflow)
  line3_output=$(build_line3 "${claude_md_count}" "${hooks_count}" "${cost}" "${active_time_str}" "${session_mins}")

  printf '%b\n%b\n%b\n' "${line1}" "${line2}" "${line3_output}"
}

main "$@"
