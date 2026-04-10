# ssh-agent — auto-start and persist across shells
#
# Reuses a running agent via a cached env file. Starts a new one if
# the cached agent is stale or missing.

_ssh_agent_env="$HOME/.ssh/agent.env"

_ssh_agent_running() {
  [[ -n "$SSH_AUTH_SOCK" ]] && ssh-add -l &>/dev/null
  local rc=$?
  # 0 = keys listed, 1 = agent running but no keys — both mean alive
  [[ $rc -eq 0 || $rc -eq 1 ]]
}

_ssh_agent_load_env() {
  [[ -f "$_ssh_agent_env" ]] && source "$_ssh_agent_env" &>/dev/null
}

_ssh_agent_start() {
  ssh-agent -s > "$_ssh_agent_env" 2>/dev/null
  chmod 600 "$_ssh_agent_env"
  source "$_ssh_agent_env" &>/dev/null
}

# --- main ---
_ssh_agent_load_env
if ! _ssh_agent_running; then
  _ssh_agent_start
fi
