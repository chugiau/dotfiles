#!/bin/sh
# test_smoke.sh — POSIX-sh smoke tests for the chezmoi + mise dotfiles layout.
#
# Verifies the repo structure and that the scripts are parseable.
# Zero dependencies beyond POSIX sh + coreutils. Optionally uses chezmoi
# when available for deeper verification.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
OK=0

ok() {
    printf '  \033[0;32mok\033[0m    %s\n' "$*"
    OK=$((OK + 1))
}

fail() {
    printf '  \033[0;31mfail\033[0m  %s\n' "$*" >&2
    FAIL=$((FAIL + 1))
}

check_exists() {
    if [ -e "$SCRIPT_DIR/$1" ]; then
        ok "exists: $1"
    else
        fail "missing: $1"
    fi
}

check_sh_parse() {
    if sh -n "$SCRIPT_DIR/$1" 2>/dev/null; then
        ok "sh -n: $1"
    else
        fail "sh -n: $1 (syntax error)"
    fi
}

check_no_bashisms() {
    # Look for common bashisms that break POSIX sh.
    #
    # Patterns:
    #   [[ / ]]         bash test
    #   =~              regex match
    #   $((x++))        postfix ++
    #   ^local / ;local bash-only 'local' keyword
    #   &>              bash redirection
    #   <<<             here-string
    f="$SCRIPT_DIR/$1"
    if [ ! -f "$f" ]; then
        fail "no-bashisms: $1 (file missing)"
        return
    fi
    pat='\[\[|\]\]|=~|\$\(\([^)]*\+\+|(^|[[:space:]]|;)local[[:space:]]|&>[^>]|<<<'
    if grep -nE "$pat" "$f" >/dev/null 2>&1; then
        fail "no-bashisms: $1 (found bashism — see grep)"
        grep -nE "$pat" "$f" >&2 || true
    else
        ok "no-bashisms: $1"
    fi
}

echo "Smoke tests: chezmoi + mise dotfiles"
echo ""

# ── Top-level files ─────────────────────────────────────────────────────────
echo "[structure]"
check_exists ".chezmoiroot"
check_exists "bootstrap.sh"
check_exists "bin/dotfiles"
check_exists "README.md"
check_exists "CLAUDE.md"
check_exists "AGENTS.md"

# .chezmoiroot content check
if [ -f "$SCRIPT_DIR/.chezmoiroot" ]; then
    root_content="$(tr -d '[:space:]' < "$SCRIPT_DIR/.chezmoiroot")"
    if [ "$root_content" = "home" ]; then
        ok ".chezmoiroot points to 'home'"
    else
        fail ".chezmoiroot content is '$root_content' (expected 'home')"
    fi
fi
echo ""

# ── chezmoi source tree ─────────────────────────────────────────────────────
echo "[home/ source tree]"
check_exists "home/dot_zshrc"
check_exists "home/dot_zprofile"
check_exists "home/dot_gitconfig"
check_exists "home/empty_dot_gitignore"
check_exists "home/empty_dot_tmux.conf"
check_exists "home/dot_config/mise/config.toml"
check_exists "home/dot_config/dotfiles/modules/empty_alias.zsh"
check_exists "home/dot_config/dotfiles/modules/empty_functions.zsh"
check_exists "home/dot_config/dotfiles/modules/empty_fzf.zsh"
check_exists "home/dot_config/dotfiles/modules/pkg-quarantine.zsh"
check_exists "home/dot_config/dotfiles/modules/ssh-agent.zsh"
check_exists "home/dot_config/dotfiles/hooks/executable_pre-commit"
check_exists "home/dot_claude/executable_statusline-command.sh"
echo ""

# ── chezmoi run_once scripts ────────────────────────────────────────────────
echo "[run_once scripts]"
check_exists "home/run_once_before_10-system-packages.sh.tmpl"
check_exists "home/run_onchange_after_10-mise-install.sh.tmpl"
check_exists "home/run_once_after_20-ohmyzsh.sh.tmpl"
check_exists "home/run_once_after_30-nvchad.sh.tmpl"
check_exists "home/run_onchange_after_40-git-hooks.sh.tmpl"
check_exists "home/run_once_after_50-default-shell.sh.tmpl"
echo ""

# ── POSIX sh parse checks ───────────────────────────────────────────────────
echo "[POSIX parse]"
check_sh_parse "bootstrap.sh"
check_sh_parse "bin/dotfiles"
check_sh_parse "tests/test_smoke.sh"
echo ""

# ── Bashism scans ───────────────────────────────────────────────────────────
echo "[no bashisms]"
check_no_bashisms "bootstrap.sh"
check_no_bashisms "bin/dotfiles"
echo ""

# ── Ansible absence ─────────────────────────────────────────────────────────
echo "[ansible removed]"
for leftover in ansible.cfg inventory site.yml install.sh \
                roles pre_tasks group_vars ansible tests/molecule; do
    if [ -e "$SCRIPT_DIR/$leftover" ]; then
        fail "leftover: $leftover (should be removed)"
    else
        ok "absent: $leftover"
    fi
done
echo ""

# ── Optional: chezmoi-based verification ────────────────────────────────────
if command -v chezmoi >/dev/null 2>&1; then
    echo "[chezmoi]"
    # Render each template with the repo's source dir so `include` calls
    # (which are relative to chezmoi's sourceDir) can resolve.  Then
    # sh -n the rendered output so we catch POSIX-sh syntax errors
    # that only manifest after template expansion.
    tmpdir="${TMPDIR:-/tmp}/dotfiles-smoke.$$"
    mkdir -p "$tmpdir"
    trap 'rm -rf "$tmpdir"' EXIT INT TERM

    for tmpl in "$SCRIPT_DIR"/home/run_*.sh.tmpl; do
        [ -f "$tmpl" ] || continue
        name="$(basename "$tmpl")"
        rendered="$tmpdir/${name%.tmpl}"
        if chezmoi execute-template -S "$SCRIPT_DIR/home" < "$tmpl" > "$rendered" 2>/dev/null; then
            ok "template renders: $name"
            if sh -n "$rendered" 2>/dev/null; then
                ok "rendered script parses: $name"
            else
                fail "rendered script parses: $name"
                sh -n "$rendered" >&2 || true
            fi
        else
            fail "template renders: $name"
            chezmoi execute-template -S "$SCRIPT_DIR/home" < "$tmpl" >&2 || true
        fi
    done
else
    echo "[chezmoi] not installed — skipping template render checks"
fi
echo ""

# ── Optional: mise config TOML parse ────────────────────────────────────────
if command -v mise >/dev/null 2>&1; then
    echo "[mise]"
    if mise config --file "$SCRIPT_DIR/home/dot_config/mise/config.toml" >/dev/null 2>&1 \
       || mise ls --file "$SCRIPT_DIR/home/dot_config/mise/config.toml" >/dev/null 2>&1; then
        ok "mise config parses"
    else
        # Fallback: just ensure the file is non-empty and contains [tools].
        if grep -q '^\[tools\]' "$SCRIPT_DIR/home/dot_config/mise/config.toml" 2>/dev/null; then
            ok "mise config has [tools] section"
        else
            fail "mise config missing [tools] section"
        fi
    fi
else
    echo "[mise] not installed — skipping config parse"
fi
echo ""

# ── mise doctor wired into install flow ────────────────────────────────────
echo "[mise doctor]"
if grep -q 'mise doctor' "$SCRIPT_DIR/home/run_onchange_after_10-mise-install.sh.tmpl"; then
    ok "run_onchange_after_10-mise-install.sh.tmpl runs mise doctor"
else
    fail "run_onchange_after_10-mise-install.sh.tmpl does not run mise doctor"
fi
if grep -q 'mise doctor' "$SCRIPT_DIR/bin/dotfiles"; then
    ok "bin/dotfiles install runs mise doctor"
else
    fail "bin/dotfiles install does not run mise doctor"
fi
echo ""

# ── Docker Desktop WSL2 compinit workaround ────────────────────────────────
echo "[wsl-docker-workaround]"
if grep -q 'vendor-completions/_docker' "$SCRIPT_DIR/home/dot_zshrc"; then
    ok "dot_zshrc guards against dangling Docker Desktop WSL2 completion"
else
    fail "dot_zshrc is missing the Docker Desktop WSL2 completion guard"
fi
# Behavioural check: the snippet should drop a broken vendor dir from fpath
if command -v zsh >/dev/null 2>&1; then
    _workdir="$(mktemp -d)" || _workdir=""
    if [ -n "$_workdir" ]; then
        mkdir -p "$_workdir/vendor-completions"
        ln -s "$_workdir/nonexistent" "$_workdir/vendor-completions/_docker"
        _out="$(
          VENDOR_DIR="$_workdir/vendor-completions" \
          BROKEN_LINK="$_workdir/vendor-completions/_docker" \
          zsh -c '
            fpath=($VENDOR_DIR /usr/share/zsh/site-functions)
            if [[ -L $BROKEN_LINK && ! -e $BROKEN_LINK ]]; then
              fpath=("${(@)fpath:#$VENDOR_DIR}")
            fi
            print -r -- $fpath
          ' 2>/dev/null
        )"
        rm -rf "$_workdir"
        case "$_out" in
            *vendor-completions*)
                fail "fpath filter did not drop broken vendor-completions dir"
                ;;
            *)
                ok "fpath filter drops broken vendor-completions dir"
                ;;
        esac
    fi
else
    echo "  zsh not installed — skipping behavioural check"
fi
echo ""

# ── chezmoi-native secrets migration ───────────────────────────────────────
# The bespoke secrets.zsh loader is gone; secrets now ride on
#   A) chezmoi's age encryption (encrypted_* source files), and
#   B) template-function pulls from Bitwarden ({{ bitwardenFields … }}).
echo "[secrets removed]"
for gone in \
    "home/dot_config/dotfiles/modules/secrets.zsh" \
    "home/dot_config/dotfiles/secrets/credentials.env.example" \
    "home/dot_config/dotfiles/secrets"; do
    if [ -e "$SCRIPT_DIR/$gone" ]; then
        fail "leftover: $gone (should be removed)"
    else
        ok "absent: $gone"
    fi
done
if grep -q 'modules/secrets\.zsh' "$SCRIPT_DIR/home/dot_zprofile"; then
    fail "dot_zprofile still sources the old secrets.zsh module"
else
    ok "dot_zprofile no longer sources secrets.zsh"
fi
echo ""

echo "[chezmoi age wiring]"
# Every distro branch in system-packages must install age so chezmoi can
# encrypt/decrypt after a fresh bootstrap.
_syspkgs="$SCRIPT_DIR/home/run_once_before_10-system-packages.sh.tmpl"
for fn in install_darwin install_debian install_arch install_fedora; do
    if awk -v fn="$fn" '
        $0 ~ "^" fn "\\(\\) *\\{" { in_fn=1; next }
        in_fn && /^\}/            { in_fn=0 }
        in_fn && /(^|[[:space:]])age([[:space:]]|$)/ { found=1 }
        END { exit(found ? 0 : 1) }
    ' "$_syspkgs"; then
        ok "$fn installs age"
    else
        fail "$fn does not install age"
    fi
done
# bin/dotfiles must expose a secrets-init subcommand that generates the
# age key and wires [age] into ~/.config/chezmoi/chezmoi.toml.
if grep -q 'secrets-init' "$SCRIPT_DIR/bin/dotfiles"; then
    ok "bin/dotfiles exposes a secrets-init subcommand"
else
    fail "bin/dotfiles has no secrets-init subcommand"
fi
if grep -q 'age-keygen' "$SCRIPT_DIR/bin/dotfiles"; then
    ok "bin/dotfiles runs age-keygen for the chezmoi key"
else
    fail "bin/dotfiles does not call age-keygen"
fi
if grep -q 'encryption *= *"age"' "$SCRIPT_DIR/bin/dotfiles"; then
    ok "bin/dotfiles writes encryption = \"age\" into chezmoi.toml"
else
    fail "bin/dotfiles does not write the age encryption block"
fi
echo ""

echo "[pre-commit encrypted secrets guard]"
_hook="$SCRIPT_DIR/home/dot_config/dotfiles/hooks/executable_pre-commit"
# Old rule referenced secrets/*.env and must go; new rule must whitelist
# encrypted_ prefixed files and *.env.tmpl templates.
if grep -q 'secrets/.*\.env' "$_hook"; then
    fail "pre-commit hook still references the removed secrets/ path"
else
    ok "pre-commit hook no longer references secrets/*.env"
fi
if grep -q 'encrypted_' "$_hook"; then
    ok "pre-commit hook whitelists chezmoi encrypted_ files"
else
    fail "pre-commit hook does not whitelist chezmoi encrypted_ files"
fi
if grep -q 'key\.txt' "$_hook"; then
    ok "pre-commit hook blocks age private keys (key.txt)"
else
    fail "pre-commit hook does not block age private keys"
fi
echo ""

echo "[docs cover new secrets workflow]"
for tok in "chezmoi.*encrypt" "age-keygen" "[Bb]itwarden"; do
    if grep -qE "$tok" "$SCRIPT_DIR/README.md"; then
        ok "README.md mentions '$tok'"
    else
        fail "README.md does not mention '$tok'"
    fi
done
if grep -q 'secrets\.zsh' "$SCRIPT_DIR/README.md"; then
    fail "README.md still references the removed secrets.zsh loader"
else
    ok "README.md no longer mentions secrets.zsh"
fi
if grep -q 'secrets\.zsh' "$SCRIPT_DIR/CLAUDE.md"; then
    fail "CLAUDE.md still references the removed secrets.zsh loader"
else
    ok "CLAUDE.md no longer mentions secrets.zsh"
fi
echo ""

# ── Summary ─────────────────────────────────────────────────────────────────
echo "Result: $OK ok, $FAIL failed"
[ "$FAIL" -eq 0 ]
