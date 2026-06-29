#!/usr/bin/env bash
# statusline/data.sh — JSON parsing, git inspection, transcript timing,
# and counters. Populates global variables read by item emitters.
#
# extract_fields and collect_git_info intentionally populate globals consumed
# by the other sourced statusline modules.
# shellcheck disable=SC2034

# extract_fields <json> — populate globals from the Claude Code statusline
# stdin payload. Missing fields default to empty string or 0; the emitters
# treat empty as "skip".
extract_fields() {
    local input="${1}"

    model_name=$(echo "${input}" | jq -r '.model.display_name // "Unknown"')
    cwd=$(echo "${input}" | jq -r '.workspace.current_dir // .cwd // ""')
    version=$(echo "${input}" | jq -r '.version // ""')
    project_dir=$(echo "${input}" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // ""')
    transcript_path=$(echo "${input}" | jq -r '.transcript_path // ""')
    session_id=$(echo "${input}" | jq -r '.session_id // ""')
    git_worktree=$(echo "${input}" | jq -r '.workspace.git_worktree // ""')

    used_pct=$(echo "${input}" | jq -r '.context_window.used_percentage // empty')
    total_input=$(echo "${input}" | jq -r '.context_window.total_input_tokens // 0')
    total_output=$(echo "${input}" | jq -r '.context_window.total_output_tokens // 0')
    cur_input=$(echo "${input}" | jq -r '.context_window.current_usage.input_tokens // empty')
    cur_output=$(echo "${input}" | jq -r '.context_window.current_usage.output_tokens // empty')
    cur_cache_write=$(echo "${input}" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
    cur_cache_read=$(echo "${input}" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

    five_hour_pct=$(echo "${input}" | jq -r '.rate_limits.five_hour.used_percentage // empty')
    five_hour_reset=$(echo "${input}" | jq -r '.rate_limits.five_hour.resets_at // empty')
    seven_day_pct=$(echo "${input}" | jq -r '.rate_limits.seven_day.used_percentage // empty')
    seven_day_reset=$(echo "${input}" | jq -r '.rate_limits.seven_day.resets_at // empty')

    total_duration_ms=$(echo "${input}" | jq -r '.cost.total_duration_ms // empty')
    total_api_duration_ms=$(echo "${input}" | jq -r '.cost.total_api_duration_ms // empty')
    total_cost=$(echo "${input}" | jq -r '.cost.total_cost_usd // empty')

    effort_level=$(echo "${input}" | jq -r '.effort.level // empty')
    output_style_name=$(echo "${input}" | jq -r '.output_style.name // empty')
    thinking_enabled=$(echo "${input}" | jq -r '.thinking.enabled // empty')
    vim_mode=$(echo "${input}" | jq -r '.vim.mode // empty')

    session_name=$(echo "${input}" | jq -r '.session_name // empty')
    repo_owner=$(echo "${input}" | jq -r '.workspace.repo.owner // empty')
    repo_name=$(echo "${input}" | jq -r '.workspace.repo.name // empty')
    pr_number=$(echo "${input}" | jq -r '.pr.number // empty')
    pr_review_state=$(echo "${input}" | jq -r '.pr.review_state // empty')
    agent_name=$(echo "${input}" | jq -r '.agent.name // empty')
}

# file_mtime <path> — modification time as Unix epoch (Linux + macOS/BSD).
file_mtime() {
    local path="${1}"
    stat -c %Y "${path}" 2>/dev/null || stat -f %m "${path}" 2>/dev/null
}

# file_btime <path> — creation (birth) time as Unix epoch. Falls back to
# the first JSONL line's `timestamp` field (Claude Code transcripts), then
# to mtime, when the filesystem doesn't track btime.
file_btime() {
    local path="${1}" b ts
    b=$(stat -c %W "${path}" 2>/dev/null || stat -f %B "${path}" 2>/dev/null)
    if [[ -z "${b}" || "${b}" == "0" || "${b}" == "-" ]]; then
        ts=$(head -n 1 "${path}" 2>/dev/null | jq -r '.timestamp // empty' 2>/dev/null)
        if [[ -n "${ts}" ]]; then
            b=$(date -d "${ts}" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%.*}" +%s 2>/dev/null)
        fi
    fi
    if [[ -z "${b}" || "${b}" == "0" ]]; then
        b=$(file_mtime "${path}")
    fi
    printf "%s" "${b}"
}

# compute_session_mins <transcript_path> — whole minutes since the
# transcript was created. Uses btime because Claude Code rewrites mtime
# on every message.
compute_session_mins() {
    local path="${1}"
    local session_mins=0

    if [[ -n "${path}" ]] && [[ -f "${path}" ]]; then
        local file_btime_val now elapsed
        file_btime_val=$(file_btime "${path}")
        now=$(date +%s)
        if [[ -n "${file_btime_val}" ]] && [[ "${file_btime_val}" =~ ^[0-9]+$ ]]; then
            elapsed=$(((now - file_btime_val) / 60))
            ((elapsed < 0)) && elapsed=0
            session_mins="${elapsed}"
        fi
    fi

    printf "%s" "${session_mins}"
}

# collect_git_info <dir> — populate git_branch, git_staged, git_modified,
# git_untracked, git_added, git_deleted, git_ahead, git_behind globals.
collect_git_info() {
    local dir="${1}"

    git_branch=""
    git_staged=0
    git_modified=0
    git_untracked=0
    git_added=0
    git_deleted=0
    git_ahead=0
    git_behind=0

    if [[ -z "${dir}" ]] || ! command -v git >/dev/null 2>&1; then
        return
    fi

    git_branch=$(git -C "${dir}" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null ||
        git -C "${dir}" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

    if [[ -z "${git_branch}" ]]; then
        return
    fi

    local line xy x y
    while IFS= read -r line; do
        xy="${line:0:2}"
        x="${xy:0:1}"
        y="${xy:1:1}"
        case "${x}" in
        A | M | D | R | C) git_staged=$((git_staged + 1)) ;;
        esac
        case "${y}" in
        M | D) git_modified=$((git_modified + 1)) ;;
        esac
        [[ "${xy}" == "??" ]] && git_untracked=$((git_untracked + 1))
    done < <(git -C "${dir}" --no-optional-locks status --porcelain 2>/dev/null)

    if [[ "${git_staged}" -gt 0 ]] || [[ "${git_modified}" -gt 0 ]]; then
        local added deleted _rest
        while IFS=$'\t' read -r added deleted _rest; do
            [[ "${added}" =~ ^[0-9]+$ ]] && git_added=$((git_added + added))
            [[ "${deleted}" =~ ^[0-9]+$ ]] && git_deleted=$((git_deleted + deleted))
        done < <(
            git -C "${dir}" --no-optional-locks diff --numstat 2>/dev/null
            git -C "${dir}" --no-optional-locks diff --cached --numstat 2>/dev/null
        )
    fi

    # Ahead/behind vs upstream tracking branch — local rev-list, no fetch.
    local ab_raw ab_ahead ab_behind
    ab_raw=$(git -C "${dir}" --no-optional-locks rev-list \
        --left-right --count 'HEAD...@{u}' 2>/dev/null)
    if [[ -n "${ab_raw}" ]]; then
        ab_ahead="${ab_raw%%$'\t'*}"
        ab_behind="${ab_raw##*$'\t'}"
        [[ "${ab_ahead}" =~ ^[0-9]+$ ]] && git_ahead="${ab_ahead}"
        [[ "${ab_behind}" =~ ^[0-9]+$ ]] && git_behind="${ab_behind}"
    fi
}

# count_claude_md <project_dir> — number of CLAUDE.md files within 5 levels.
count_claude_md() {
    local dir="${1}"
    if [[ -n "${dir}" ]] && [[ -d "${dir}" ]]; then
        find "${dir}" -maxdepth 5 -name "CLAUDE.md" 2>/dev/null | wc -l | tr -d ' '
    else
        printf "0"
    fi
}

# count_hooks — number of hook entries declared in settings.json (preferred)
# or hook script files under the hooks dir as a fallback.
count_hooks() {
    local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    local hooks_dir="${claude_dir}/hooks"
    local settings_file="${claude_dir}/settings.json"
    local count=0

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

# count_subagents <session_id> — sub-agent counter file written by the
# subagent-tracker hook.
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
