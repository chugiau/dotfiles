#
# Secrets Loader
#
# Sources all secrets/*.env files from $DOTFILES/secrets/
# Warns if a *.env.example template has no corresponding *.env file.
#

__secrets_load() {
  local secrets_dir="${DOTFILES:-$HOME/.dotfiles}/secrets"

  # Source all .env files
  for f in "$secrets_dir"/*.env(N); do
    source "$f"
  done

  # Warn about missing .env files for each .env.example template
  for tmpl in "$secrets_dir"/*.env.example(N); do
    local env_file="${tmpl%.example}"
    if [[ ! -f "$env_file" ]]; then
      printf '\033[1;33m[secrets]\033[0m missing %s — copy from %s\n' \
        "${env_file:t}" "${tmpl:t}" >&2
    fi
  done
}

__secrets_load
