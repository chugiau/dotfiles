#!/bin/sh
# Block Codex prompts and tool calls that target local secret files.

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

extract_prompt() {
    printf "%s" "$input" | jq -r ".prompt // \"\""
}

extract_tool_name() {
    printf "%s" "$input" | jq -r ".tool_name // \"\""
}

extract_tool_command() {
    printf "%s" "$input" | jq -r ".tool_input.command // \"\""
}

extract_tool_text() {
    printf "%s" "$input" | jq -r ".tool_input // {} | tostring"
}

extract_path_field_values() {
    printf "%s" "$input" | jq -r "
        .tool_input // {} |
        paths(scalars) as \$p |
        select((\$p[-1] | tostring | ascii_downcase | test(\"path|file|filename|target|cwd\"))) |
        getpath(\$p)
    "
}

to_lower() {
    printf "%s" "$1" | tr "[:upper:]" "[:lower:]"
}

normalize_tokens() {
    printf "%s\n" "$1" | tr "\n\r\t\",;()[]{}<>" "                  "
}

trim_token() {
    token=$1
    while :; do
        case "$token" in
        *[.:!?])
            token=${token%?}
            ;;
        *)
            printf "%s" "$token"
            return 0
            ;;
        esac
    done
}

is_ssh_path() {
    token=$1
    dot=$(printf "\056")
    ssh_name=${dot}ssh

    case "$token" in
    "~/$ssh_name" | "~/$ssh_name/"* | *"/$ssh_name" | *"/$ssh_name/"* | "$ssh_name" | "$ssh_name/"*)
        return 0
        ;;
    esac

    return 1
}

ssh_tail() {
    token=$1
    dot=$(printf "\056")
    ssh_name=${dot}ssh

    case "$token" in
    "~/$ssh_name" | *"/$ssh_name" | "$ssh_name")
        printf ""
        ;;
    "~/$ssh_name/"*)
        printf "%s" "${token#~/$ssh_name/}"
        ;;
    *"/$ssh_name/"*)
        printf "%s" "${token##*/$ssh_name/}"
        ;;
    "$ssh_name/"*)
        printf "%s" "${token#$ssh_name/}"
        ;;
    esac
}

is_allowed_ssh_path() {
    token=$1
    tail=$(ssh_tail "$token")

    case "$tail" in
    config | config.d | config.d/*)
        return 0
        ;;
    *.pub)
        case "$tail" in
        */*)
            return 1
            ;;
        *)
            return 0
            ;;
        esac
        ;;
    esac

    return 1
}

is_sensitive_path() {
    token=$(trim_token "$1")
    dot=$(printf "\056")
    env_name=${dot}env

    if is_ssh_path "$token"; then
        if is_allowed_ssh_path "$token"; then
            return 1
        fi
        return 0
    fi

    base=${token##*/}
    case "$base" in
    "$env_name" | "$env_name".* | "${env_name}rc" | *"$env_name"*)
        return 0
        ;;
    esac

    return 1
}

contains_sensitive_path_token() {
    lower=$(to_lower "$1")

    for token in $(normalize_tokens "$lower"); do
        if is_sensitive_path "$token"; then
            return 0
        fi
    done

    return 1
}

contains_sensitive_explicit_path() {
    lower=$(to_lower "$1")

    for token in $(normalize_tokens "$lower"); do
        case "$token" in
        */* | ~/*)
            if is_sensitive_path "$token"; then
                return 0
            fi
            ;;
        esac
    done

    return 1
}

prompt_requests_file_access() {
    lower=$(to_lower "$1")

    case "$lower" in
    *"read "* | *"show "* | *"print "* | *"open "* | *"cat "* | *"edit "* | *"write "* | *"access "* | *"load "* | *"dump "*)
        return 0
        ;;
    esac

    return 1
}

contains_sensitive_prompt_target() {
    prompt=$1

    if contains_sensitive_explicit_path "$prompt"; then
        return 0
    fi

    if prompt_requests_file_access "$prompt" && contains_sensitive_path_token "$prompt"; then
        return 0
    fi

    return 1
}

command_name_from_tokens() {
    for token in "$@"; do
        case "$token" in
        -* | *=*)
            continue
            ;;
        sudo | command | builtin | env)
            continue
            ;;
        *)
            printf "%s\n" "$token"
            return 0
            ;;
        esac
    done

    printf "\n"
}

contains_sensitive_command_target() {
    lower=$(to_lower "$1")
    # shellcheck disable=SC2046
    set -- $(normalize_tokens "$lower")
    command_name=$(command_name_from_tokens "$@")

    for token in "$@"; do
        case "$token" in
        */* | ~/*)
            if is_sensitive_path "$token"; then
                return 0
            fi
            ;;
        esac
    done

    case "$command_name" in
    cat | sed | awk | head | tail | less | more | nl | wc | file | strings | stat | readlink | realpath | cp | mv | rm | chmod | chown | touch | vi | vim | nvim | nano | code | cursor)
        for token in "$@"; do
            case "$token" in
            -* | "$command_name")
                continue
                ;;
            esac
            if is_sensitive_path "$token"; then
                return 0
            fi
        done
        ;;
    esac

    return 1
}

contains_sensitive_patch_target() {
    patch=$1

    while IFS= read -r line; do
        case "$line" in
        "*** Add File: "* | "*** Update File: "* | "*** Delete File: "* | "*** Move to: "*)
            target=${line#*: }
            if is_sensitive_path "$(to_lower "$target")"; then
                return 0
            fi
            ;;
        esac
    done <<EOF
$patch
EOF

    return 1
}

contains_sensitive_pretool_target() {
    tool_name=$(extract_tool_name)

    case "$tool_name" in
    Bash)
        contains_sensitive_command_target "$(extract_tool_command)"
        return $?
        ;;
    apply_patch)
        contains_sensitive_patch_target "$(extract_tool_text)"
        return $?
        ;;
    esac

    path_values=$(extract_path_field_values) ||
        block_closed "Sensitive-file guard could not inspect tool input."

    if contains_sensitive_path_token "$path_values"; then
        return 0
    fi

    return 1
}

emit_user_prompt_block() {
    jq -cn "{
        decision: \"block\",
        reason: \"Sensitive local file access is blocked before model processing.\"
    }"
}

emit_tool_block() {
    jq -cn "{
        hookSpecificOutput: {
            hookEventName: \"PreToolUse\",
            permissionDecision: \"deny\",
            permissionDecisionReason: \"Sensitive local file access is blocked by policy.\"
        }
    }"
}

case "$event" in
UserPromptSubmit)
    if contains_sensitive_prompt_target "$(extract_prompt)"; then
        emit_user_prompt_block
    fi
    ;;
PreToolUse)
    if contains_sensitive_pretool_target; then
        emit_tool_block
    fi
    ;;
esac
