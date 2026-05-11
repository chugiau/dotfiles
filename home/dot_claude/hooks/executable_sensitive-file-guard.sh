#!/bin/sh
# Block Claude Code prompts and tool calls that target local secret files.

set -eu

block_closed() {
    printf '%s\n' "$1" >&2
    exit 2
}

if ! command -v jq >/dev/null 2>&1; then
    block_closed "Sensitive-file guard requires jq; blocking by default."
fi

input=$(cat)

event=$(printf '%s' "$input" | jq -r '.hook_event_name // ""') ||
    block_closed "Sensitive-file guard could not parse hook input."

extract_text() {
    case "$event" in
    UserPromptSubmit)
        printf '%s' "$input" | jq -r '.prompt // ""'
        ;;
    PreToolUse)
        printf '%s' "$input" | jq -r '
            [
                (.tool_name // ""),
                (.tool_input // {} | tostring)
            ] | join("\n")
        '
        ;;
    *)
        printf ''
        ;;
    esac
}

contains_sensitive_target() {
    lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')

    case "$lower" in
    *'/.ssh'* | *'.ssh/'* | *'.ssh')
        return 0
        ;;
    esac

    case "$lower" in
    *'.env'*)
        return 0
        ;;
    esac

    return 1
}

emit_user_prompt_block() {
    jq -cn '{
        decision: "block",
        reason: "Sensitive local file access is blocked before model processing."
    }'
}

emit_tool_block() {
    jq -cn '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: "Sensitive local file access is blocked by policy."
        }
    }'
}

text=$(extract_text) || block_closed "Sensitive-file guard could not inspect hook input."

if contains_sensitive_target "$text"; then
    case "$event" in
    UserPromptSubmit)
        emit_user_prompt_block
        ;;
    PreToolUse)
        emit_tool_block
        ;;
    *)
        block_closed "Sensitive local file access is blocked by policy."
        ;;
    esac
fi
