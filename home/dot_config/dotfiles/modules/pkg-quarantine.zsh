#
# Package Quarantine - Supply Chain Security
#
# Prevents installing packages published less than N days ago.
# Configurable via:
#   PKG_QUARANTINE_DAYS  - quarantine period in days (default: 7)
#   PKG_QUARANTINE_SKIP  - set to 1 to disable all checks
#
# Bypass per-command: append --no-quarantine
#
# Supported: pip, uv, pipx, poetry | npm, pnpm, yarn, bun
#

: ${PKG_QUARANTINE_DAYS:=7}

# ── Core: check a single package against its registry ────────────────────────

__pkg_quarantine_check() {
  local registry="$1" pkg="$2"
  local name version publish_date age_days

  case "$registry" in
    pypi)
      # Strip extras [foo] and version specifiers
      name="${pkg%%\[*}"
      name="${name%%[>=<\!~]*}"
      # Normalize: lowercase, hyphens
      name="${(L)name//_/-}"
      [[ -z "$name" ]] && return 0

      local json
      json="$(curl -sf --max-time 5 "https://pypi.org/pypi/${name}/json" 2>/dev/null)" || return 0

      version="$(printf '%s' "$json" | jq -r '.info.version // empty' 2>/dev/null)" || return 0
      [[ -z "$version" ]] && return 0

      publish_date="$(printf '%s' "$json" | jq -r --arg v "$version" '
        (.releases[$v] // [])[0].upload_time_iso_8601 //
        (.releases[$v] // [])[0].upload_time //
        empty
      ' 2>/dev/null)" || return 0
      ;;
    npm)
      # Handle scoped packages: @scope/name@version
      if [[ "$pkg" == @*/* ]]; then
        # Scoped: strip version after second @
        name="${pkg%@*}"
        [[ "$name" == "$pkg" ]] || true  # no version pinned is fine
        # If stripping removed the scope, keep full name
        [[ "$name" == */* ]] || name="$pkg"
      else
        name="${pkg%%@*}"
      fi
      [[ -z "$name" ]] && return 0

      local json
      json="$(curl -sf --max-time 5 "https://registry.npmjs.org/${name}" 2>/dev/null)" || return 0

      version="$(printf '%s' "$json" | jq -r '.["dist-tags"].latest // empty' 2>/dev/null)" || return 0
      [[ -z "$version" ]] && return 0

      publish_date="$(printf '%s' "$json" | jq -r --arg v "$version" '.time[$v] // empty' 2>/dev/null)" || return 0
      ;;
    *)
      return 0
      ;;
  esac

  [[ -z "$publish_date" ]] && return 0

  local publish_epoch now_epoch
  publish_epoch="$(date -d "$publish_date" +%s 2>/dev/null)" || return 0
  now_epoch="$(date +%s)"
  age_days=$(( (now_epoch - publish_epoch) / 86400 ))

  if (( age_days < PKG_QUARANTINE_DAYS )); then
    printf '\033[1;31m[quarantine]\033[0m %s %s was published %d day(s) ago (%s) — blocked (minimum: %d days)\n' \
      "$name" "$version" "$age_days" "$publish_date" "$PKG_QUARANTINE_DAYS" >&2
    return 1
  fi
  return 0
}

# ── Extract package names from argument lists ────────────────────────────────

__pkg_quarantine_extract_pypi() {
  # Flags that consume the next argument
  local -a consuming=(-r --requirement -c --constraint -e --editable -t --target
    -i --index-url --extra-index-url --prefix --root --src -b --build
    --python --config-settings --config-setting --group)
  local skip_next=0
  for arg in "$@"; do
    if (( skip_next )); then
      skip_next=0
      continue
    fi
    # Check consuming flags
    if (( ${consuming[(Ie)$arg]} )); then
      skip_next=1
      continue
    fi
    # Skip any flag
    [[ "$arg" == -* ]] && continue
    # Skip URLs and local paths
    [[ "$arg" == http://* || "$arg" == https://* || "$arg" == .* || "$arg" == /* || "$arg" == */* ]] && continue
    # Skip . (current directory install)
    [[ "$arg" == "." ]] && continue
    echo "$arg"
  done
}

__pkg_quarantine_extract_npm() {
  local -a consuming=(--registry --prefix --workspace -w --cache)
  local skip_next=0
  for arg in "$@"; do
    if (( skip_next )); then
      skip_next=0
      continue
    fi
    if (( ${consuming[(Ie)$arg]} )); then
      skip_next=1
      continue
    fi
    [[ "$arg" == -* ]] && continue
    [[ "$arg" == http://* || "$arg" == https://* || "$arg" == .* || "$arg" == /* ]] && continue
    [[ "$arg" == "." ]] && continue
    echo "$arg"
  done
}

# ── Generic wrapper builder ──────────────────────────────────────────────────

__pkg_quarantine_wrap() {
  local cmd="$1" registry="$2"
  shift 2
  local -a trigger_subs=("$@")

  # Check bypass
  if [[ "$PKG_QUARANTINE_SKIP" == "1" ]]; then
    return 0  # signal: pass through
  fi

  # Read real args from the caller's context via $__pq_args
  local -a args=("${__pq_args[@]}")

  # Check --no-quarantine
  local no_quarantine=0
  local -a clean_args=()
  for arg in "${args[@]}"; do
    if [[ "$arg" == "--no-quarantine" ]]; then
      no_quarantine=1
    else
      clean_args+=("$arg")
    fi
  done
  if (( no_quarantine )); then
    __pq_args=("${clean_args[@]}")
    return 0
  fi

  # Find the subcommand
  local subcmd="" subcmd_idx=0
  local idx=0
  for arg in "${args[@]}"; do
    if [[ "$arg" != -* ]]; then
      if (( ${trigger_subs[(Ie)$arg]} )); then
        subcmd="$arg"
        subcmd_idx=$idx
        break
      fi
    fi
    (( idx++ ))
  done

  # No matching subcommand → pass through
  [[ -z "$subcmd" ]] && return 0

  # Extract packages from args after the subcommand
  local -a post_args=("${args[@]:$((subcmd_idx + 1))}")
  local -a packages=()

  if [[ "$registry" == "pypi" ]]; then
    packages=("${(@f)$(__pkg_quarantine_extract_pypi "${post_args[@]}")}")
  else
    packages=("${(@f)$(__pkg_quarantine_extract_npm "${post_args[@]}")}")
  fi

  # Remove empty entries
  packages=("${(@)packages:#}")

  # No packages to check → pass through
  (( ${#packages} == 0 )) && return 0

  # Check each package
  local blocked=0
  for pkg in "${packages[@]}"; do
    __pkg_quarantine_check "$registry" "$pkg" || blocked=1
  done

  if (( blocked )); then
    printf '\033[1;33m[quarantine]\033[0m Install aborted. Use --no-quarantine or PKG_QUARANTINE_SKIP=1 to bypass.\n' >&2
    return 1
  fi
  return 0
}

# ── Wrapper functions ────────────────────────────────────────────────────────

pip() {
  local -a __pq_args=("$@")
  __pkg_quarantine_wrap pip pypi install || return $?
  command pip "${__pq_args[@]}"
}

pipx() {
  local -a __pq_args=("$@")
  __pkg_quarantine_wrap pipx pypi install upgrade || return $?
  command pipx "${__pq_args[@]}"
}

poetry() {
  local -a __pq_args=("$@")
  __pkg_quarantine_wrap poetry pypi add update || return $?
  command poetry "${__pq_args[@]}"
}

uv() {
  local -a __pq_args=("$@")

  # uv has two forms: "uv pip install ..." and "uv add ..."
  if [[ "$1" == "pip" ]]; then
    # Shift perspective: check args[2..] for "install"
    local -a inner_args=("${@:2}")
    local -a __pq_args_inner=("${inner_args[@]}")
    local subcmd_found=0
    for arg in "${inner_args[@]}"; do
      if [[ "$arg" == "install" ]]; then
        subcmd_found=1
        break
      fi
    done
    if (( subcmd_found )); then
      local -a __pq_args=("${inner_args[@]}")
      __pkg_quarantine_wrap "uv pip" pypi install || return $?
      command uv pip "${__pq_args[@]}"
      return $?
    fi
  fi

  __pkg_quarantine_wrap uv pypi add || return $?
  command uv "${__pq_args[@]}"
}

npm() {
  local -a __pq_args=("$@")
  __pkg_quarantine_wrap npm npm install i add || return $?
  command npm "${__pq_args[@]}"
}

pnpm() {
  local -a __pq_args=("$@")
  __pkg_quarantine_wrap pnpm npm add i install || return $?
  command pnpm "${__pq_args[@]}"
}

yarn() {
  local -a __pq_args=("$@")
  __pkg_quarantine_wrap yarn npm add || return $?
  command yarn "${__pq_args[@]}"
}

bun() {
  local -a __pq_args=("$@")
  __pkg_quarantine_wrap bun npm add i install || return $?
  command bun "${__pq_args[@]}"
}
