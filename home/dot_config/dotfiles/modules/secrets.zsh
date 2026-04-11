#
# Secrets Loader
#
# Sources all secrets/*.env files from $DOTFILES/secrets/.
# When a *.env.example template has no corresponding *.env file the
# warning is *deferred* to the first precmd hook — emitting it while
# .zprofile/.zshrc are still running would be captured by p10k's
# instant-prompt console-output guard and disable instant prompt on
# subsequent logins.
#

__secrets_load() {
  local secrets_dir="${DOTFILES:-$HOME/.dotfiles}/secrets"

  # Source every .env file silently.
  local f
  for f in "$secrets_dir"/*.env(N); do
    source "$f"
  done

  # Collect any missing secrets templates. Stash them in a global so the
  # deferred hook can pick them up after the shell finishes initialising.
  typeset -g -a __SECRETS_MISSING
  __SECRETS_MISSING=()
  local tmpl env_file
  for tmpl in "$secrets_dir"/*.env.example(N); do
    env_file="${tmpl%.example}"
    [[ -f "$env_file" ]] && continue
    __SECRETS_MISSING+=("${env_file:t}:${tmpl:t}")
  done

  # Nothing missing → nothing to defer.
  (( ${#__SECRETS_MISSING[@]} == 0 )) && return 0

  # Only nag interactive shells; non-interactive logins (cron, scp) shouldn't
  # spam stderr and shouldn't need a hook either.
  [[ -o interactive ]] || return 0

  autoload -Uz add-zsh-hook
  add-zsh-hook precmd __secrets_warn_once
}

# One-shot precmd hook: emit the warnings then deregister itself, so the
# notification appears exactly once after the first real prompt renders.
__secrets_warn_once() {
  local entry name tmpl
  for entry in "${__SECRETS_MISSING[@]}"; do
    name="${entry%%:*}"
    tmpl="${entry#*:}"
    printf '\033[1;33m[secrets]\033[0m missing %s — copy from %s\n' \
      "$name" "$tmpl" >&2
  done
  autoload -Uz add-zsh-hook
  add-zsh-hook -d precmd __secrets_warn_once
  unset __SECRETS_MISSING
  unset -f __secrets_warn_once
}

__secrets_load
