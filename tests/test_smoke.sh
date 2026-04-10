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
check_exists "home/dot_gitignore"
check_exists "home/dot_tmux.conf"
check_exists "home/dot_config/mise/config.toml"
check_exists "home/dot_config/dotfiles/modules/alias.zsh"
check_exists "home/dot_config/dotfiles/modules/functions.zsh"
check_exists "home/dot_config/dotfiles/modules/fzf.zsh"
check_exists "home/dot_config/dotfiles/modules/pkg-quarantine.zsh"
check_exists "home/dot_config/dotfiles/modules/secrets.zsh"
check_exists "home/dot_config/dotfiles/modules/ssh-agent.zsh"
check_exists "home/dot_config/dotfiles/hooks/executable_pre-commit"
check_exists "home/dot_config/dotfiles/secrets/credentials.env.example"
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
    # (which are relative to chezmoi's sourceDir) can resolve.
    for tmpl in "$SCRIPT_DIR"/home/run_*.sh.tmpl; do
        [ -f "$tmpl" ] || continue
        name="$(basename "$tmpl")"
        if chezmoi execute-template -S "$SCRIPT_DIR/home" < "$tmpl" > /dev/null 2>&1; then
            ok "template renders: $name"
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

# ── Summary ─────────────────────────────────────────────────────────────────
echo "Result: $OK ok, $FAIL failed"
[ "$FAIL" -eq 0 ]
