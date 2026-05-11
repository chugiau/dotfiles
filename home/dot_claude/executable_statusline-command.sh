#!/usr/bin/env bash
# statusline-command.sh — Claude Code statusline entrypoint.
#
# Reads a JSON payload from stdin (provided by Claude Code), populates a
# flat list of display items, detects the terminal width, and lets the
# packer wrap them into 1-5 lines while dropping low-priority items
# when space is tight.
#
# See specs/021-responsive-statusline.md for the architecture.
# Compatibility: bash 3.2+, macOS and Linux.
#
# The statusline modules share globals through source order; ShellCheck cannot
# infer every cross-file assignment from the dynamic source path.
# shellcheck disable=SC1091,SC2034,SC2154

_PATH_EXTRA="/usr/local/bin:/usr/bin:/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin"
export PATH="${_PATH_EXTRA}:${PATH}"

_SLDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=statusline/core.sh
. "${_SLDIR}/statusline/core.sh"
# shellcheck source=statusline/data.sh
. "${_SLDIR}/statusline/data.sh"
# shellcheck source=statusline/width.sh
. "${_SLDIR}/statusline/width.sh"
# shellcheck source=statusline/items.sh
. "${_SLDIR}/statusline/items.sh"
# shellcheck source=statusline/layout.sh
. "${_SLDIR}/statusline/layout.sh"

main() {
    if ! command -v jq >/dev/null 2>&1; then
        printf "claude statusline: jq not found in PATH\n" >&2
        exit 0
    fi

    local input
    input=$(cat)

    extract_fields "${input}"
    collect_git_info "${cwd}"

    session_mins=$(compute_session_mins "${transcript_path}")
    active_time_str=$(format_active_time "${total_duration_ms}")
    api_duration_str=$(format_api_duration "${total_api_duration_ms}")
    subagent_count=$(count_subagents "${session_id}")
    claude_md_count=$(count_claude_md "${project_dir}")
    hooks_count=$(count_hooks)

    ctx_pct=0
    [[ -n "${used_pct}" ]] && ctx_pct=$(printf "%.0f" "${used_pct}")

    cost=""
    if [[ -n "${total_cost}" ]] && [[ "${total_cost}" != "null" ]] && [[ "${total_cost}" != "0" ]]; then
        cost=$(printf "\$%.4f" "${total_cost}")
    fi

    emit_all

    local width
    width=$(detect_columns)

    layout_pack "${width}"
    layout_render "${width}"
}

main "$@"
