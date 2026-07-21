#!/bin/sh
# test_smoke.sh — POSIX-sh smoke tests for the chezmoi + mise dotfiles layout.
#
# Verifies the repo structure and that the scripts are parseable.
# Zero dependencies beyond POSIX sh + coreutils. Optionally uses chezmoi
# when available for deeper verification.
#
# Many checks grep for literal shell snippets containing `$...`; single quotes
# are intentional there.
# shellcheck disable=SC2016

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

check_git_ignored() {
    if git -C "$SCRIPT_DIR" check-ignore --no-index -q -- "$1"; then
        ok "gitignore ignores: $1"
    else
        fail "gitignore does not ignore: $1"
    fi
}

check_git_visible() {
    if git -C "$SCRIPT_DIR" check-ignore --no-index -q -- "$1"; then
        fail "gitignore hides shareable file: $1"
    else
        ok "gitignore keeps visible: $1"
    fi
}

echo "Smoke tests: chezmoi + mise dotfiles"
echo ""

# ── Top-level files ─────────────────────────────────────────────────────────
echo "[structure]"
check_exists ".chezmoiroot"
check_exists ".editorconfig"
check_exists ".gitattributes"
check_exists ".gitignore"
check_exists "bootstrap.sh"
check_exists "bootstrap.ps1"
check_exists "bin/dotfiles"
check_exists "bin/dotfiles.ps1"
check_exists "README.md"
check_exists "CLAUDE.md"
check_exists "AGENTS.md"
check_exists "tests/bats/dotfiles_cli.bats"
check_exists "tests/windows_smoke.ps1"
for f in .editorconfig .gitattributes .gitignore; do
    if [ -s "$SCRIPT_DIR/$f" ]; then
        ok "non-empty: $f"
    else
        fail "empty: $f"
    fi
done

# .chezmoiroot content check
if [ -f "$SCRIPT_DIR/.chezmoiroot" ]; then
    root_content="$(tr -d '[:space:]' <"$SCRIPT_DIR/.chezmoiroot")"
    if [ "$root_content" = "home" ]; then
        ok ".chezmoiroot points to 'home'"
    else
        fail ".chezmoiroot content is '$root_content' (expected 'home')"
    fi
fi
echo ""

# ── Local environment ignore policy (spec 031) ────────────────────────────────
echo "[gitignore local environment policy]"
_dot='.'
_env='env'
_dotenv="${_dot}${_env}"
_envrc="${_dotenv}rc"
_direnv="${_dot}dir${_env}"
_credentials="credentials${_dot}${_env}"
for ignored in \
    "$_dotenv" \
    "project/$_dotenv" \
    "${_dotenv}.local" \
    "project/${_dotenv}.production.local" \
    "$_credentials" \
    "project/$_credentials" \
    "$_envrc" \
    "project/$_envrc" \
    "${_direnv}/cache" \
    "project/${_direnv}/cache"; do
    check_git_ignored "$ignored"
done
for visible in \
    "${_dotenv}.example" \
    "project/${_dotenv}.sample" \
    "project/service${_dot}${_env}.example" \
    "project/service${_dot}${_env}.tmpl"; do
    check_git_visible "$visible"
done
echo ""

# ── chezmoi source tree ─────────────────────────────────────────────────────
echo "[home/ source tree]"
check_exists "home/dot_zshrc"
check_exists "home/dot_zprofile"
check_exists "home/dot_zshenv.tmpl"
check_exists "home/.chezmoiignore"
check_exists "home/dot_gitconfig"
check_exists "home/empty_dot_gitignore"
check_exists "home/empty_dot_tmux.conf"
check_exists "home/dot_config/mise/config.toml"
check_exists "home/dot_config/direnv/direnv.toml"
check_exists "home/dot_config/dotfiles/modules/empty_alias.zsh"
check_exists "home/dot_config/dotfiles/modules/empty_functions.zsh"
check_exists "home/dot_config/dotfiles/modules/empty_fzf.zsh"
check_exists "home/dot_config/dotfiles/modules/auth-unlock.zsh"
check_exists "home/dot_config/dotfiles/modules/pkg-quarantine.zsh"
check_exists "home/dot_config/dotfiles/modules/ssh-agent.zsh"
check_exists "home/dot_config/dotfiles/bin/executable_pinentry-auto"
check_exists "home/dot_config/dotfiles/hooks/executable_pre-commit"
check_exists "home/dot_config/dotfiles/powershell/profile.ps1"
check_exists "home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
check_exists "home/private_dot_gnupg/gpg-agent.conf.tmpl"
check_exists "home/dot_claude/executable_statusline-command.sh"
check_exists "home/dot_claude/hooks/executable_sensitive-file-guard.sh"
check_exists "home/dot_codex/hooks/executable_sensitive-file-guard.sh"
echo ""

# ── chezmoi run_once scripts ────────────────────────────────────────────────
echo "[run_once scripts]"
check_exists "home/run_once_before_10-system-packages.sh.tmpl"
check_exists "home/run_once_before_05-windows-packages.ps1.tmpl"
check_exists "home/run_onchange_after_10-mise-install.sh.tmpl"
check_exists "home/run_onchange_after_11-mise-windows.ps1.tmpl"
check_exists "home/run_once_after_12-codex-windows.ps1.tmpl"
check_exists "home/run_onchange_after_15-neovim.sh.tmpl"
check_exists "home/run_once_after_20-ohmyzsh.sh.tmpl"
check_exists "home/run_once_after_30-nvchad.sh.tmpl"
check_exists "home/run_onchange_after_40-git-hooks.sh.tmpl"
check_exists "home/run_onchange_after_41-ssh-config-auth.sh.tmpl"
check_exists "home/run_onchange_after_42-gpg-agent-auth.sh.tmpl"
check_exists "home/run_once_after_50-default-shell.sh.tmpl"
check_exists "home/run_onchange_after_60-claude-statusline.sh.tmpl"
check_exists "home/run_onchange_after_61-claude-env.sh.tmpl"
check_exists "home/run_onchange_after_62-claude-security.sh.tmpl"
check_exists "home/run_onchange_after_63-codex-security.sh.tmpl"
echo ""

# ── POSIX sh parse checks ───────────────────────────────────────────────────
echo "[POSIX parse]"
check_sh_parse "bootstrap.sh"
check_sh_parse "bin/dotfiles"
check_sh_parse "tests/test_smoke.sh"
check_sh_parse "home/dot_claude/hooks/executable_sensitive-file-guard.sh"
check_sh_parse "home/dot_codex/hooks/executable_sensitive-file-guard.sh"
echo ""

# ── Windows PowerShell support (spec 033) ──────────────────────────────────
echo "[Windows dotfiles]"
if grep -q 'winget install --id \$Id' "$SCRIPT_DIR/bootstrap.ps1" &&
    grep -q 'Git.Git' "$SCRIPT_DIR/bootstrap.ps1" &&
    grep -q 'twpayne.chezmoi' "$SCRIPT_DIR/bootstrap.ps1" &&
    grep -q 'jdx.mise' "$SCRIPT_DIR/bootstrap.ps1"; then
    ok "bootstrap.ps1 installs Windows prerequisites through winget"
else
    fail "bootstrap.ps1 does not install Git, chezmoi, and mise through winget"
fi
if grep -q 'chezmoi apply' "$SCRIPT_DIR/bootstrap.ps1"; then
    ok "bootstrap.ps1 runs chezmoi apply"
else
    fail "bootstrap.ps1 does not run chezmoi apply"
fi
if grep -q 'tests/windows_smoke.ps1' "$SCRIPT_DIR/bin/dotfiles.ps1"; then
    ok "bin/dotfiles.ps1 test runs the Windows smoke suite"
else
    fail "bin/dotfiles.ps1 test does not run the Windows smoke suite"
fi
if grep -q 'mise activate pwsh' "$SCRIPT_DIR/home/dot_config/dotfiles/powershell/profile.ps1" &&
    grep -q 'hook pwsh' "$SCRIPT_DIR/home/dot_config/dotfiles/powershell/profile.ps1"; then
    ok "PowerShell profile wires mise and direnv"
else
    fail "PowerShell profile does not wire mise and direnv"
fi
if grep -qF "Join-Path \$HOME '.local\\share\\mise\\shims'" "$SCRIPT_DIR/home/dot_config/dotfiles/powershell/profile.ps1" &&
    grep -q 'LOCALAPPDATA' "$SCRIPT_DIR/home/dot_config/dotfiles/powershell/profile.ps1"; then
    ok "PowerShell profile exposes mise shims for Windows IDEs"
else
    fail "PowerShell profile does not expose mise shims for Windows IDEs"
fi
if grep -q 'direnv.direnv' "$SCRIPT_DIR/home/run_once_before_05-windows-packages.ps1.tmpl" &&
    grep -q 'Get-Command direnv.exe' "$SCRIPT_DIR/home/dot_config/dotfiles/powershell/profile.ps1" &&
    grep -q 'IsNullOrWhiteSpace' "$SCRIPT_DIR/home/dot_config/dotfiles/powershell/profile.ps1"; then
    ok "PowerShell profile uses native Windows direnv with empty-hook guard"
else
    fail "PowerShell profile does not guard native Windows direnv hook"
fi
# slimfat is the default oh-my-posh theme on native Windows (spec 039),
# behind a user-dropped theme.omp.json / default.omp.json override.
if grep -q 'slimfat.omp.json' "$SCRIPT_DIR/home/dot_config/dotfiles/powershell/profile.ps1"; then
    ok "PowerShell profile defaults to the slimfat oh-my-posh theme"
else
    fail "PowerShell profile does not default to the slimfat oh-my-posh theme"
fi
# Native Windows installs Codex CLI via OpenAI's official irm | iex
# one-liner instead of through mise or npm (spec 040) — install.sh
# explicitly refuses to run outside macOS/Linux, and mise's bare `codex`
# shorthand can resolve to the npm backend.
_codex_win_installer="$SCRIPT_DIR/home/run_once_after_12-codex-windows.ps1.tmpl"
if [ -f "$_codex_win_installer" ] &&
    grep -q 'IsWindows' "$_codex_win_installer" &&
    grep -q 'irm https://chatgpt.com/codex/install.ps1 | iex' "$_codex_win_installer" &&
    ! grep -q 'npm install' "$_codex_win_installer" &&
    grep -q 'irm https://chatgpt.com/codex/install.ps1 | iex' "$SCRIPT_DIR/bin/dotfiles.ps1"; then
    ok "native Windows installs and updates Codex CLI via the official irm | iex one-liner, no npm"
else
    fail "native Windows does not install/update Codex CLI via the official irm | iex one-liner"
fi
if grep -q '^05-windows-packages\.ps1$' "$SCRIPT_DIR/home/.chezmoiignore" &&
    grep -q '^11-mise-windows\.ps1$' "$SCRIPT_DIR/home/.chezmoiignore" &&
    grep -q '^12-codex-windows\.ps1$' "$SCRIPT_DIR/home/.chezmoiignore" &&
    grep -q '^10-system-packages\.sh$' "$SCRIPT_DIR/home/.chezmoiignore" &&
    grep -q '^63-codex-security\.sh$' "$SCRIPT_DIR/home/.chezmoiignore"; then
    ok ".chezmoiignore splits Windows and Unix run scripts by target script name"
else
    fail ".chezmoiignore does not split Windows and Unix run scripts by target script name"
fi
if grep -q '^\.config/dotfiles/powershell/$' "$SCRIPT_DIR/home/.chezmoiignore" &&
    grep -q '^\.config/dotfiles/modules/$' "$SCRIPT_DIR/home/.chezmoiignore"; then
    ok ".chezmoiignore uses target paths for dot_config directories"
else
    fail ".chezmoiignore does not use target paths for dot_config directories"
fi
echo ""

# ── Bashism scans ───────────────────────────────────────────────────────────
echo "[no bashisms]"
check_no_bashisms "bootstrap.sh"
check_no_bashisms "bin/dotfiles"
echo ""

# ── Bootstrap apt diagnostics (specs 024, 043) ─────────────────────────────
echo "[bootstrap apt diagnostics]"
_bootstrap="$SCRIPT_DIR/bootstrap.sh"
if grep -q 'Updating apt package indexes' "$_bootstrap"; then
    ok "bootstrap logs apt index refresh before apt-get update"
else
    fail "bootstrap does not log apt index refresh before apt-get update"
fi
if grep -nE 'apt-get[[:space:]]+update([[:space:]].*)?-qq' "$_bootstrap" >/dev/null 2>&1; then
    fail "bootstrap still runs apt-get update in quiet mode"
else
    ok "bootstrap does not run apt-get update in quiet mode"
fi
if grep -q 'Acquire::http::Timeout' "$_bootstrap" &&
    grep -q 'Acquire::https::Timeout' "$_bootstrap"; then
    ok "bootstrap configures apt acquire timeouts"
else
    fail "bootstrap does not configure apt acquire timeouts"
fi
if grep -q 'Acquire::Retries' "$_bootstrap"; then
    ok "bootstrap configures apt acquire retries"
else
    fail "bootstrap does not configure apt acquire retries"
fi
if grep -q 'APT::Update::Error-Mode=any' "$_bootstrap"; then
    fail "bootstrap forces APT::Update::Error-Mode=any, so an unrelated optional/third-party repo warning aborts bootstrap"
else
    ok "bootstrap does not hard-fail apt update on an optional/third-party repo warning"
fi
if grep -q 'broken apt source' "$_bootstrap"; then
    ok "bootstrap explains apt update failure likely source"
else
    fail "bootstrap apt update failure diagnostic does not mention broken apt source"
fi
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
    ignored="$(chezmoi ignored -S "$SCRIPT_DIR/home" 2>/dev/null || true)"
    if printf '%s\n' "$ignored" | grep -q '^05-windows-packages\.ps1$' &&
        printf '%s\n' "$ignored" | grep -q '^11-mise-windows\.ps1$' &&
        printf '%s\n' "$ignored" | grep -q '^\.config/dotfiles/powershell$'; then
        ok "non-Windows chezmoi ignore excludes Windows target scripts and profile module"
    else
        fail "non-Windows chezmoi ignore excludes Windows target scripts and profile module"
        printf '%s\n' "$ignored" >&2
    fi

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
        if chezmoi execute-template -S "$SCRIPT_DIR/home" <"$tmpl" >"$rendered" 2>/dev/null; then
            ok "template renders: $name"
            if sh -n "$rendered" 2>/dev/null; then
                ok "rendered script parses: $name"
            else
                fail "rendered script parses: $name"
                sh -n "$rendered" >&2 || true
            fi
        else
            fail "template renders: $name"
            chezmoi execute-template -S "$SCRIPT_DIR/home" <"$tmpl" >&2 || true
        fi
    done
else
    echo "[chezmoi] not installed — skipping template render checks"
fi
echo ""

# ── Optional: mise config TOML parse ────────────────────────────────────────
if command -v mise >/dev/null 2>&1; then
    echo "[mise]"
    if mise config --file "$SCRIPT_DIR/home/dot_config/mise/config.toml" >/dev/null 2>&1 ||
        mise ls --file "$SCRIPT_DIR/home/dot_config/mise/config.toml" >/dev/null 2>&1; then
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
# pnpm must NOT be declared — spec 019 retires pnpm in favour of bun
# as the sole JS package manager managed by these dotfiles. Mirrors
# the spec-005 pattern used to assert neovim is no longer mise-managed.
_misecfg="$SCRIPT_DIR/home/dot_config/mise/config.toml"
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*pnpm[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    fail "mise config still declares pnpm (spec 019 — bun replaces pnpm)"
else
    ok "mise config no longer declares pnpm (spec 019)"
fi
# bun must be declared so `bun` ships on every machine via mise shims,
# removing the need for the ~/.bun PATH-shadow setup in dot_zshrc.
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*bun[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares bun under [tools]"
else
    fail "mise config does not declare bun under [tools]"
fi
# eza must use the aqua backend so native Windows installs pull the
# upstream binary instead of resolving the bare shorthand to cargo:eza,
# which requires a Rust toolchain that these dotfiles do not install.
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*"aqua:eza-community\/eza"[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares eza through aqua backend"
else
    fail "mise config does not declare eza through aqua backend (spec 034)"
fi
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*eza[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    fail "mise config still declares bare eza shorthand (spec 034)"
else
    ok "mise config does not declare bare eza shorthand"
fi
# node must be declared so `node`, `npm`, and `npx` ship on every
# machine via mise shims (spec 006 — pinned to the LTS alias so
# `dotfiles update` rides every LTS point release automatically).
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*node[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares node under [tools]"
else
    fail "mise config does not declare node under [tools]"
fi
# gh (GitHub CLI) must be declared so every machine has `gh` on PATH
# via mise shims (spec 008 — Claude Code's `gh pr create` / `gh pr
# view` flows depend on it).
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*gh[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares gh under [tools]"
else
    fail "mise config does not declare gh under [tools]"
fi
# glab (GitLab CLI) must be declared for the same reason as gh — it
# rides the gitlab:gitlab-org/cli backend in mise's registry (spec 008).
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*glab[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares glab under [tools]"
else
    fail "mise config does not declare glab under [tools]"
fi
# codex (OpenAI Codex CLI) must be declared so POSIX/WSL2 machines ship the
# terminal coding agent alongside Claude Code via mise shims (spec 011).
# It carries an os = ["linux", "macos"] filter so native Windows skips the
# mise install entirely and uses the official installer instead (spec 040).
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*codex[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares codex under [tools]"
else
    fail "mise config does not declare codex under [tools]"
fi
if grep -q 'os = \["linux", "macos"\]' "$_misecfg"; then
    ok "mise config excludes codex from native Windows (spec 040)"
else
    fail "mise config does not exclude codex from native Windows (spec 040)"
fi
# gcloud must be declared so any existing Google Cloud CLI shim has an active
# version during login-shell startup (spec 037). Without this, startup hooks or
# completions that execute `gcloud` surface mise's "No version is set for shim"
# error before the prompt is usable.
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*gcloud[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares gcloud under [tools]"
else
    fail "mise config does not declare gcloud under [tools] (spec 037)"
fi
# direnv must be declared so every machine ships the per-directory env
# loader alongside the rest of the toolchain (spec 012 — aqua:direnv/direnv
# backend pulls the static release binary).  The dot_zshrc hook + the
# global direnv.toml in home/dot_config/direnv/ are asserted lower down.
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*direnv[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares direnv under [tools]"
else
    fail "mise config does not declare direnv under [tools]"
fi
# ripgrep must be declared so every machine ships a current `rg` via mise
# shims (spec 015 — aqua:BurntSushi/ripgrep backend pulls the upstream
# static release binary, shadowing any distro-packaged ripgrep).
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*ripgrep[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares ripgrep under [tools]"
else
    fail "mise config does not declare ripgrep under [tools]"
fi
# bats must be declared as a mise-managed test tool (spec 025).  The
# registry name is "bats" even though the upstream project is Bats-core.
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*bats[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares bats under [tools]"
else
    fail "mise config does not declare bats under [tools] (spec 025)"
fi
# ShellCheck must be declared as a mise-managed static analysis tool
# (spec 027) so `dotfiles test` runs the lint gate after setup.
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*shellcheck[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares shellcheck under [tools]"
else
    fail "mise config does not declare shellcheck under [tools] (spec 027)"
fi
# shfmt must be declared for the same test-toolchain reason as ShellCheck;
# the static gate is already wired into bin/dotfiles.
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*shfmt[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares shfmt under [tools]"
else
    fail "mise config does not declare shfmt under [tools] (spec 027)"
fi
# bin/dotfiles doctor must check for node so a missing install surfaces
# directly rather than as a cryptic downstream LSP / hook failure.
if grep -qE '^[[:space:]]*for cmd in[^;]*[[:space:]]node[[:space:]]' "$SCRIPT_DIR/bin/dotfiles"; then
    ok "bin/dotfiles doctor loop checks node"
else
    fail "bin/dotfiles doctor loop does not check node"
fi
# neovim must NOT be declared under mise — it ships from the upstream
# pre-built tarball now (spec 005) so root / sudoedit / cron can find it
# on /usr/local/bin instead of through the mise shim dir, which only the
# interactive zsh rc puts on PATH.
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*neovim[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    fail "mise config still declares neovim (should be installed from tarball — spec 005)"
else
    ok "mise config no longer declares neovim"
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

# ── Bats test framework (spec 025) ─────────────────────────────────────────
echo "[bats test framework]"
if grep -qE '^[[:space:]]*test\)' "$SCRIPT_DIR/bin/dotfiles"; then
    ok "bin/dotfiles exposes a test subcommand"
else
    fail "bin/dotfiles does not expose a test subcommand"
fi
if grep -q 'tests/test_smoke.sh' "$SCRIPT_DIR/bin/dotfiles"; then
    ok "bin/dotfiles test runs the POSIX smoke test"
else
    fail "bin/dotfiles test does not run tests/test_smoke.sh"
fi
if grep -q 'bats tests/bats' "$SCRIPT_DIR/bin/dotfiles"; then
    ok "bin/dotfiles test runs the Bats suite"
else
    fail "bin/dotfiles test does not run bats tests/bats"
fi
if grep -q 'Bats' "$SCRIPT_DIR/README.md" &&
    grep -q 'dotfiles test' "$SCRIPT_DIR/README.md"; then
    ok "README.md documents Bats and dotfiles test"
else
    fail "README.md does not document Bats and dotfiles test"
fi
if grep -q 'Bats' "$SCRIPT_DIR/AGENTS.md" &&
    grep -q 'dotfiles test' "$SCRIPT_DIR/AGENTS.md"; then
    ok "AGENTS.md documents Bats and dotfiles test"
else
    fail "AGENTS.md does not document Bats and dotfiles test"
fi
if grep -q '@test ' "$SCRIPT_DIR/tests/bats/dotfiles_cli.bats"; then
    ok "Bats suite contains executable test cases"
else
    fail "Bats suite does not contain executable test cases"
fi
echo ""

# ── Docker Desktop WSL2 compinit workaround ────────────────────────────────
echo "[mise activate]"
# dot_zshrc must run `mise activate zsh` so the shell session picks up
# shims + hook-env; without this, tools installed by mise are invisible
# in login shells even though `mise` itself is on PATH.
if grep -q 'mise activate zsh' "$SCRIPT_DIR/home/dot_zshrc"; then
    ok "dot_zshrc activates mise"
else
    fail "dot_zshrc does not activate mise (eval \"\$(mise activate zsh)\")"
fi
if grep -q 'mise activate zsh --shims' "$SCRIPT_DIR/home/dot_zshrc"; then
    fail "dot_zshrc uses shim-only mise activation (interactive shells need hook-env mode)"
else
    ok "dot_zshrc keeps interactive mise activation in hook-env mode"
fi
# The activation must be guarded so a machine without mise still loads.
if awk '
    /mise activate zsh/ && prev ~ /command -v mise/ { found=1 }
    { prev = $0 }
    END { exit(found ? 0 : 1) }
' "$SCRIPT_DIR/home/dot_zshrc"; then
    ok "mise activation is guarded by command -v mise"
else
    fail "mise activation is not guarded by command -v mise"
fi
# mise activate must run AFTER every `export PATH=...:$PATH` prepend in
# dot_zshrc (spec 007), otherwise the mise shim dir ends up behind
# ~/.bun, ~/.dotnet, ~/.local/share/pnpm, and ~/.local/share/fnm —
# which is exactly the "mise tool paths are not first in PATH" warning
# that `mise doctor` raises on a fresh shell. Walks the file top-down
# and records the last-seen prepend and the mise-activate line, then
# fails if any prepend comes after the activate.
if awk '
    /mise activate zsh/        { mise_line = NR }
    /export PATH=.*:\$PATH/    { last_path = NR }
    END { exit(mise_line && last_path < mise_line ? 0 : 1) }
' "$SCRIPT_DIR/home/dot_zshrc"; then
    ok "mise activate runs after all PATH prepends in dot_zshrc"
else
    fail "mise activate runs before a PATH prepend in dot_zshrc (spec 007)"
fi
echo ""

echo "[dot_zshrc guards]"
_zshrc="$SCRIPT_DIR/home/dot_zshrc"
# bun: block must be guarded on the standalone bun binary existing so a
# machine without ~/.bun stops prepending a phantom path (which is what
# trips mise doctor's "tool paths are not first in PATH" warning).
if grep -q '\[ -x "\$HOME/.bun/bin/bun" \]' "$_zshrc"; then
    ok "dot_zshrc guards bun setup on \$HOME/.bun/bin/bun"
else
    fail "dot_zshrc does not guard bun setup on \$HOME/.bun/bin/bun"
fi
if awk '
    /BUN_INSTALL=/ && $0 !~ /^[[:space:]]/ { bad = 1 }
    END { exit(bad ? 1 : 0) }
' "$_zshrc"; then
    ok "dot_zshrc has no unindented BUN_INSTALL export (i.e. it is inside a guard)"
else
    fail "dot_zshrc still exports BUN_INSTALL unconditionally"
fi
# dotnet: likewise guarded on the dotnet binary itself existing, not just
# the ~/.dotnet directory (which can linger as cruft without a real
# dotnet install).
if grep -q '\[ -x "\$HOME/.dotnet/dotnet" \]' "$_zshrc"; then
    ok "dot_zshrc guards dotnet setup on \$HOME/.dotnet/dotnet"
else
    fail "dot_zshrc does not guard dotnet setup on \$HOME/.dotnet/dotnet"
fi
if awk '
    /DOTNET_ROOT=/ && $0 !~ /^[[:space:]]/ { bad = 1 }
    END { exit(bad ? 1 : 0) }
' "$_zshrc"; then
    ok "dot_zshrc has no unindented DOTNET_ROOT export"
else
    fail "dot_zshrc still exports DOTNET_ROOT unconditionally"
fi
# Homebrew: shellenv eval must be guarded so Linux boxes without brew
# do not print an error on every new shell.
if grep -q '^eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv' "$_zshrc"; then
    fail "dot_zshrc still calls linuxbrew shellenv unconditionally"
else
    ok "dot_zshrc no longer calls linuxbrew shellenv unconditionally"
fi
# NB: the spec-003 "dot_zshrc still wires brew shellenv" assertion retired
# in spec 004 — brew shellenv moved to dot_zprofile per Homebrew's own
# install script. The [dot_zprofile] section below asserts the wireup.
# pnpm: spec 019 retires pnpm entirely.  No PNPM_HOME export, no
# pnpm-conditional block, no pnpm completion generation should remain.
if grep -q 'PNPM_HOME' "$_zshrc"; then
    fail "dot_zshrc still references PNPM_HOME (spec 019 — pnpm is retired)"
else
    ok "dot_zshrc has zero PNPM_HOME references (spec 019)"
fi
if grep -q 'command -v pnpm' "$_zshrc"; then
    fail "dot_zshrc still has a 'command -v pnpm' guard (spec 019 — pnpm is retired)"
else
    ok "dot_zshrc no longer guards on command -v pnpm (spec 019)"
fi
# Spec 007 amendment: the bun and dotnet blocks must APPEND to
# PATH (`"$PATH:..."`), not prepend (`"...:$PATH"`). `mise activate`
# runs in hook-env mode and splices its tool paths into a slot
# computed from PATH at eval time, which empirically lands *after*
# any prepended non-mise entries — so the only way to keep mise
# shims genuinely first is to never prepend these fallback stanzas.
# Positive pattern uses fixed strings via grep -F to dodge escaping.
# bun:
if grep -qF 'export PATH="$PATH:$BUN_INSTALL/bin"' "$_zshrc"; then
    ok "dot_zshrc appends BUN_INSTALL/bin to PATH (spec 007 amendment)"
else
    fail "dot_zshrc does not append BUN_INSTALL/bin (expected: export PATH=\"\$PATH:\$BUN_INSTALL/bin\")"
fi
if grep -qF 'export PATH="$BUN_INSTALL/bin:$PATH"' "$_zshrc"; then
    fail "dot_zshrc still prepends BUN_INSTALL/bin (spec 007 amendment forbids this)"
else
    ok "dot_zshrc no longer prepends BUN_INSTALL/bin"
fi
# dotnet:
if grep -qF 'export PATH="$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools"' "$_zshrc"; then
    ok "dot_zshrc appends DOTNET_ROOT[/tools] to PATH (spec 007 amendment)"
else
    fail "dot_zshrc does not append DOTNET_ROOT[/tools] (expected: export PATH=\"\$PATH:\$DOTNET_ROOT:\$DOTNET_ROOT/tools\")"
fi
if grep -qF 'export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"' "$_zshrc"; then
    fail "dot_zshrc still prepends DOTNET_ROOT[/tools] (spec 007 amendment forbids this)"
else
    ok "dot_zshrc no longer prepends DOTNET_ROOT[/tools]"
fi
echo ""

# ── Shell profile split (spec 004): zshenv / zprofile / zshrc by purpose ──
# Retargeted to dot_zshenv.tmpl by spec 009 — BROWSER is now dispatched
# at apply time, so the source lives in a chezmoi template.
echo "[dot_zshenv]"
_zshenv="$SCRIPT_DIR/home/dot_zshenv.tmpl"
if [ -f "$_zshenv" ]; then
    for sym in 'DOTFILES_REPO=' 'DOTFILES=' 'EDITOR=' 'VISUAL=' 'BROWSER=' 'DOTNET_CLI_TELEMETRY_OPTOUT='; do
        if grep -q "$sym" "$_zshenv"; then
            ok "dot_zshenv exports $sym"
        else
            fail "dot_zshenv does not export $sym"
        fi
    done
    if grep -q '\$HOME/bin:\$HOME/.local/bin' "$_zshenv"; then
        ok "dot_zshenv prepends \$HOME/bin:\$HOME/.local/bin to PATH"
    else
        fail "dot_zshenv does not prepend \$HOME/bin:\$HOME/.local/bin to PATH"
    fi
    if grep -q '\$DOTFILES_REPO/shellscripts' "$_zshenv"; then
        ok "dot_zshenv prepends \$DOTFILES_REPO/shellscripts to PATH"
    else
        fail "dot_zshenv does not prepend \$DOTFILES_REPO/shellscripts to PATH"
    fi
    if awk '
        $0 !~ /^[[:space:]]*#/ && /mise activate/ { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "$_zshenv"; then
        fail "dot_zshenv runs mise activate (should stay pure env)"
    else
        ok "dot_zshenv does not run mise activate"
    fi
    if awk '
        $0 !~ /^[[:space:]]*#/ && /command -v mise/ { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "$_zshenv"; then
        fail "dot_zshenv probes for mise (should stay pure env)"
    else
        ok "dot_zshenv does not probe for mise"
    fi
fi
echo ""

echo "[dot_zprofile]"
_zprof="$SCRIPT_DIR/home/dot_zprofile"
# Hoisted env must be gone from dot_zprofile — it lives in dot_zshenv now.
for sym in 'DOTFILES_REPO=' 'DOTFILES=' 'EDITOR=' 'VISUAL=' 'BROWSER=' 'DOTNET_CLI_TELEMETRY_OPTOUT='; do
    if grep -q "$sym" "$_zprof"; then
        fail "dot_zprofile still exports $sym (should be in dot_zshenv)"
    else
        ok "dot_zprofile no longer exports $sym"
    fi
done
# Claude-Code-scoped env must not leak into the login shell.
if grep -q 'ENABLE_LSP_TOOL' "$_zprof"; then
    fail "dot_zprofile still exports ENABLE_LSP_TOOL (should be in settings.json.env)"
else
    ok "dot_zprofile no longer exports ENABLE_LSP_TOOL"
fi
# Fcitx5 startup moved to environment.d + XDG autostart (spec 045).
# dot_zprofile is login-shell-scoped and never reaches the systemd
# --user session GNOME actually launches apps from, so it must no
# longer touch fcitx5 at all.
if grep -qi 'fcitx5' "$_zprof"; then
    fail "dot_zprofile still references fcitx5 (moved to environment.d + autostart)"
else
    ok "dot_zprofile no longer references fcitx5"
fi
# Homebrew shellenv loop moves from dot_zshrc into dot_zprofile.
if grep -q 'shellenv zsh' "$_zprof"; then
    ok "dot_zprofile wires brew shellenv (received from dot_zshrc)"
else
    fail "dot_zprofile does not wire brew shellenv"
fi
if grep -q '^eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv' "$_zprof"; then
    fail "dot_zprofile has an unguarded linuxbrew shellenv call"
else
    ok "dot_zprofile has no unguarded linuxbrew shellenv call"
fi
if grep -q 'mise activate zsh --shims' "$_zprof"; then
    ok "dot_zprofile activates mise shims for IDE-launched tools"
else
    fail "dot_zprofile does not activate mise shims for IDE-launched tools"
fi
if awk '
    /if command -v mise >/ { in_guard = 1 }
    in_guard && /mise activate zsh --shims/ { found = 1 }
    in_guard && /^fi$/ { in_guard = 0 }
    END { exit(found ? 0 : 1) }
' "$_zprof"; then
    ok "dot_zprofile guards mise shim activation"
else
    fail "dot_zprofile does not guard mise shim activation"
fi
if awk '
    /shellenv zsh/ { brew_line = NR }
    /mise activate zsh --shims/ { mise_line = NR }
    END { exit(brew_line && mise_line && brew_line < mise_line ? 0 : 1) }
' "$_zprof"; then
    ok "dot_zprofile loads mise shims after Homebrew shellenv"
else
    fail "dot_zprofile does not load mise shims after Homebrew shellenv"
fi
echo ""

echo "[fcitx5 autostart]"
_fcitx_envd="$SCRIPT_DIR/home/dot_config/environment.d/fcitx5.conf"
check_exists "home/dot_config/environment.d/fcitx5.conf"
if [ -f "$_fcitx_envd" ]; then
    for sym in 'GTK_IM_MODULE=fcitx' 'QT_IM_MODULE=fcitx' 'QT_IM_MODULES=wayland;fcitx' \
        'XMODIFIERS=@im=fcitx' 'SDL_IM_MODULE=fcitx' 'GLFW_IM_MODULE=ibus'; do
        if grep -qF "$sym" "$_fcitx_envd"; then
            ok "fcitx5.conf sets $sym"
        else
            fail "fcitx5.conf does not set $sym"
        fi
    done
fi
_fcitx_autostart="$SCRIPT_DIR/home/dot_config/autostart/org.fcitx.Fcitx5.desktop"
check_exists "home/dot_config/autostart/org.fcitx.Fcitx5.desktop"
if [ -f "$_fcitx_autostart" ]; then
    if grep -q '^\[Desktop Entry\]' "$_fcitx_autostart"; then
        ok "org.fcitx.Fcitx5.desktop has a [Desktop Entry] header"
    else
        fail "org.fcitx.Fcitx5.desktop is missing a [Desktop Entry] header"
    fi
    if grep -q '^TryExec=fcitx5$' "$_fcitx_autostart"; then
        ok "org.fcitx.Fcitx5.desktop guards on TryExec=fcitx5"
    else
        fail "org.fcitx.Fcitx5.desktop does not guard on TryExec=fcitx5"
    fi
fi
echo ""

echo "[dot_zshrc profile-split leftovers]"
# Base PATH bootstrap moves to dot_zshenv, must be gone from dot_zshrc.
if grep -q 'export PATH=\$HOME/bin:\$HOME/.local/bin' "$_zshrc"; then
    fail "dot_zshrc still has the base \$HOME/bin PATH prepend"
else
    ok "dot_zshrc no longer has the base \$HOME/bin PATH prepend"
fi
# Brew shellenv moves to dot_zprofile, must be gone from dot_zshrc.
if grep -q 'shellenv zsh' "$_zshrc"; then
    fail "dot_zshrc still wires brew shellenv (should be in dot_zprofile)"
else
    ok "dot_zshrc no longer wires brew shellenv"
fi
# Stock oh-my-zsh commented boilerplate must be trimmed.
for marker in CASE_SENSITIVE HYPHEN_INSENSITIVE DISABLE_MAGIC_FUNCTIONS \
    DISABLE_LS_COLORS DISABLE_AUTO_TITLE ENABLE_CORRECTION \
    COMPLETION_WAITING_DOTS DISABLE_UNTRACKED_FILES_DIRTY \
    HIST_STAMPS ZSH_CUSTOM ZSH_THEME_RANDOM_CANDIDATES; do
    if grep -q "$marker" "$_zshrc"; then
        fail "dot_zshrc still carries stock oh-my-zsh boilerplate: $marker"
    else
        ok "dot_zshrc trimmed: $marker"
    fi
done
# The four active oh-my-zsh lines must stay.
for keep in 'ZSH="\$HOME/.oh-my-zsh"' 'ZSH_THEME=' 'plugins=(' 'source \$ZSH/oh-my-zsh.sh'; do
    if grep -q "$keep" "$_zshrc"; then
        ok "dot_zshrc still has active oh-my-zsh line: $keep"
    else
        fail "dot_zshrc dropped active oh-my-zsh line: $keep"
    fi
done
echo ""

# ── Claude Code env wireup (spec 004) ──────────────────────────────────────
echo "[claude env wireup]"
_envtmpl="$SCRIPT_DIR/home/run_onchange_after_61-claude-env.sh.tmpl"
if command -v chezmoi >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && [ -f "$_envtmpl" ]; then
    _stage="${TMPDIR:-/tmp}/dotfiles-claude-env.$$"
    mkdir -p "$_stage"
    _rendered="$_stage/run.sh"
    if chezmoi execute-template -S "$SCRIPT_DIR/home" <"$_envtmpl" >"$_rendered" 2>/dev/null; then
        chmod +x "$_rendered"

        # Scenario 1: no settings.json — file is created with env.ENABLE_LSP_TOOL="1".
        _h1="$_stage/h1"
        mkdir -p "$_h1/.claude"
        if HOME="$_h1" "$_rendered" >/dev/null 2>&1 &&
            [ -f "$_h1/.claude/settings.json" ] &&
            [ "$(jq -r '.env.ENABLE_LSP_TOOL' "$_h1/.claude/settings.json")" = "1" ]; then
            ok "creates settings.json with env.ENABLE_LSP_TOOL when missing"
        else
            fail "did not create settings.json with env.ENABLE_LSP_TOOL when missing"
        fi

        # Scenario 2: unrelated env keys and unrelated top-level keys must survive.
        _h2="$_stage/h2"
        mkdir -p "$_h2/.claude"
        printf '%s\n' '{"env":{"FOO":"bar"},"statusLine":{"type":"command","command":"x","padding":0},"autoMemoryEnabled":false}' \
            >"$_h2/.claude/settings.json"
        if HOME="$_h2" "$_rendered" >/dev/null 2>&1 &&
            [ "$(jq -r '.env.FOO' "$_h2/.claude/settings.json")" = "bar" ] &&
            [ "$(jq -r '.env.ENABLE_LSP_TOOL' "$_h2/.claude/settings.json")" = "1" ] &&
            [ "$(jq -r '.statusLine.type' "$_h2/.claude/settings.json")" = "command" ] &&
            [ "$(jq -r '.autoMemoryEnabled' "$_h2/.claude/settings.json")" = "false" ]; then
            ok "preserves unrelated env and top-level keys when merging ENABLE_LSP_TOOL"
        else
            fail "did not preserve unrelated keys when merging ENABLE_LSP_TOOL"
        fi

        # Scenario 3: idempotency — second run leaves the file untouched.
        _h3="$_stage/h3"
        mkdir -p "$_h3/.claude"
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _mt1=$(stat -c %Y "$_h3/.claude/settings.json" 2>/dev/null ||
            stat -f %m "$_h3/.claude/settings.json" 2>/dev/null)
        sleep 1
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _mt2=$(stat -c %Y "$_h3/.claude/settings.json" 2>/dev/null ||
            stat -f %m "$_h3/.claude/settings.json" 2>/dev/null)
        if [ "$_mt1" = "$_mt2" ]; then
            ok "idempotent: second run does not rewrite settings.json"
        else
            fail "idempotent: second run rewrote settings.json (mtime changed)"
        fi
    else
        fail "could not render run_onchange_after_61-claude-env.sh.tmpl"
    fi
    rm -rf "$_stage"
else
    echo "  chezmoi/jq/template missing — skipping behavioural checks"
fi
echo ""

# ── Claude Code sensitive-file guard (spec 029) ────────────────────────────
echo "[claude sensitive-file guard]"
_guard="$SCRIPT_DIR/home/dot_claude/hooks/executable_sensitive-file-guard.sh"
_security_tmpl="$SCRIPT_DIR/home/run_onchange_after_62-claude-security.sh.tmpl"

if [ -f "$_guard" ]; then
    _stage="${TMPDIR:-/tmp}/dotfiles-claude-guard.$$"
    mkdir -p "$_stage"

    _run_guard() {
        _fixture="$1"
        _prefix="$2"
        printf '%s\n' "$_fixture" |
            "$_guard" >"$_stage/${_prefix}.out" 2>"$_stage/${_prefix}.err"
    }

    _allowed_prompt='{"hook_event_name":"UserPromptSubmit","prompt":"Show git status."}'
    if _run_guard "$_allowed_prompt" allowed_prompt &&
        [ ! -s "$_stage/allowed_prompt.out" ] &&
        [ ! -s "$_stage/allowed_prompt.err" ]; then
        ok "guard allows unrelated UserPromptSubmit input"
    else
        fail "guard blocks or prints output for unrelated UserPromptSubmit input"
    fi

    _blocked_prompt='{"hook_event_name":"UserPromptSubmit","prompt":"Read ~/.ssh/id_ed25519 for me."}'
    if _run_guard "$_blocked_prompt" blocked_prompt &&
        jq -e '.decision == "block"' "$_stage/blocked_prompt.out" >/dev/null &&
        ! grep -q 'id_ed25519\|\.ssh' "$_stage/blocked_prompt.out"; then
        ok "guard blocks SSH-key prompt before model processing without echoing path"
    else
        fail "guard does not block SSH-key prompt cleanly"
    fi

    _blocked_bash='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat .env.local"}}'
    if _run_guard "$_blocked_bash" blocked_bash &&
        jq -e '.hookSpecificOutput.permissionDecision == "deny"' "$_stage/blocked_bash.out" >/dev/null &&
        ! grep -q '\.env.local' "$_stage/blocked_bash.out"; then
        ok "guard denies Bash tool calls that target env-like files"
    else
        fail "guard does not deny Bash env-like file access cleanly"
    fi

    _blocked_read='{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/project/.env"}}'
    if _run_guard "$_blocked_read" blocked_read &&
        jq -e '.hookSpecificOutput.permissionDecision == "deny"' "$_stage/blocked_read.out" >/dev/null &&
        ! grep -q '\.env' "$_stage/blocked_read.out"; then
        ok "guard denies Read tool calls that target env-like files"
    else
        fail "guard does not deny Read env-like file access cleanly"
    fi

    _allowed_read='{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/project/README.md"}}'
    if _run_guard "$_allowed_read" allowed_read &&
        [ ! -s "$_stage/allowed_read.out" ] &&
        [ ! -s "$_stage/allowed_read.err" ]; then
        ok "guard allows unrelated PreToolUse input"
    else
        fail "guard blocks or prints output for unrelated PreToolUse input"
    fi

    rm -rf "$_stage"
else
    fail "missing Claude sensitive-file guard hook"
fi

if grep -q 'executable_sensitive-file-guard.sh' "$SCRIPT_DIR/bin/dotfiles"; then
    ok "dotfiles test includes the Claude sensitive-file guard"
else
    fail "dotfiles test does not include the Claude sensitive-file guard"
fi

if command -v chezmoi >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 &&
    [ -f "$_security_tmpl" ]; then
    _stage="${TMPDIR:-/tmp}/dotfiles-claude-security.$$"
    mkdir -p "$_stage"
    _rendered="$_stage/run.sh"
    if chezmoi execute-template -S "$SCRIPT_DIR/home" <"$_security_tmpl" >"$_rendered" 2>/dev/null; then
        chmod +x "$_rendered"

        _h1="$_stage/h1"
        mkdir -p "$_h1/.claude"
        if HOME="$_h1" "$_rendered" >/dev/null 2>&1 &&
            jq -e '
                .permissions.deny | index("Read(~/.ssh/**)") and
                index("Read(**/.env)") and
                index("Read(**/.env.*)") and
                index("Read(**/*.env)") and
                index("Read(**/*.env.*)")
            ' "$_h1/.claude/settings.json" >/dev/null &&
            [ "$(jq -r '.permissions.disableBypassPermissionsMode' "$_h1/.claude/settings.json")" = "disable" ] &&
            [ "$(jq -r '.sandbox.enabled' "$_h1/.claude/settings.json")" = "true" ] &&
            [ "$(jq -r '.sandbox.failIfUnavailable' "$_h1/.claude/settings.json")" = "true" ] &&
            jq -e '.hooks.UserPromptSubmit[]?.hooks[]?.command | endswith("/.claude/hooks/sensitive-file-guard.sh")' \
                "$_h1/.claude/settings.json" >/dev/null &&
            jq -e '.hooks.PreToolUse[]? |
                select(.matcher == "Read|Glob|Grep|Bash|Edit|MultiEdit|Write|Agent") |
                .hooks[]?.command | endswith("/.claude/hooks/sensitive-file-guard.sh")' \
                "$_h1/.claude/settings.json" >/dev/null; then
            ok "security merge creates permissions, sandbox, and hook settings"
        else
            fail "security merge did not create expected Claude settings"
        fi

        _h2="$_stage/h2"
        mkdir -p "$_h2/.claude"
        printf '%s\n' '{"env":{"FOO":"bar"},"statusLine":{"type":"command","command":"x","padding":0},"permissions":{"deny":["Read(./secrets/**)"]}}' \
            >"$_h2/.claude/settings.json"
        if HOME="$_h2" "$_rendered" >/dev/null 2>&1 &&
            [ "$(jq -r '.env.FOO' "$_h2/.claude/settings.json")" = "bar" ] &&
            [ "$(jq -r '.statusLine.type' "$_h2/.claude/settings.json")" = "command" ] &&
            jq -e '.permissions.deny | index("Read(./secrets/**)") and index("Read(~/.ssh/**)")' \
                "$_h2/.claude/settings.json" >/dev/null; then
            ok "security merge preserves unrelated settings and existing deny rules"
        else
            fail "security merge disturbed unrelated settings or existing deny rules"
        fi

        _h3="$_stage/h3"
        mkdir -p "$_h3/.claude"
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _mt1=$(stat -c %Y "$_h3/.claude/settings.json" 2>/dev/null ||
            stat -f %m "$_h3/.claude/settings.json" 2>/dev/null)
        sleep 1
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _mt2=$(stat -c %Y "$_h3/.claude/settings.json" 2>/dev/null ||
            stat -f %m "$_h3/.claude/settings.json" 2>/dev/null)
        if [ "$_mt1" = "$_mt2" ]; then
            ok "security merge is idempotent"
        else
            fail "security merge rewrote an already-current settings.json"
        fi
    else
        fail "could not render run_onchange_after_62-claude-security.sh.tmpl"
    fi
    rm -rf "$_stage"
else
    echo "  chezmoi/jq/template missing — skipping security merge behavioural checks"
fi
echo ""

# ── Codex sensitive-file guard (spec 030) ──────────────────────────────────
echo "[codex sensitive-file guard]"
_codex_guard="$SCRIPT_DIR/home/dot_codex/hooks/executable_sensitive-file-guard.sh"
_codex_security_tmpl="$SCRIPT_DIR/home/run_onchange_after_63-codex-security.sh.tmpl"

if [ -f "$_codex_guard" ]; then
    _stage="${TMPDIR:-/tmp}/dotfiles-codex-guard.$$"
    _fake_home="$_stage/home"
    _fake_project="$_stage/project"
    _fake_key="$_fake_home/.ssh/id_ed25519"
    _fake_ssh_config="$_fake_home/.ssh/config"
    _fake_ssh_include="$_fake_home/.ssh/config.d/work"
    _fake_pub_key="$_fake_home/.ssh/id_ed25519.pub"
    _fake_env="$_fake_project/.env.local"
    _fake_key_canary="DOTFILES_TEST_FAKE_PRIVATE_KEY_CANARY"
    _fake_env_canary="DOTFILES_TEST_FAKE_ENV_CANARY"
    mkdir -p "$_fake_home/.ssh/config.d" "$_fake_project"
    printf '%s\n' \
        '-----BEGIN OPENSSH PRIVATE KEY-----' \
        "$_fake_key_canary" \
        '-----END OPENSSH PRIVATE KEY-----' \
        >"$_fake_key"
    printf '%s\n' \
        'Host example' \
        '    HostName example.invalid' \
        >"$_fake_ssh_config"
    printf '%s\n' \
        'Host work' \
        '    HostName work.invalid' \
        >"$_fake_ssh_include"
    printf '%s\n' \
        'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakePublicKeyOnly dotfiles-test' \
        >"$_fake_pub_key"
    printf '%s\n' \
        "API_TOKEN=$_fake_env_canary" \
        >"$_fake_env"

    _run_codex_guard() {
        _fixture="$1"
        _prefix="$2"
        printf '%s\n' "$_fixture" |
            "$_codex_guard" >"$_stage/${_prefix}.out" 2>"$_stage/${_prefix}.err"
    }

    _allowed_prompt='{"hook_event_name":"UserPromptSubmit","prompt":"Summarize README.md."}'
    if _run_codex_guard "$_allowed_prompt" allowed_prompt &&
        [ ! -s "$_stage/allowed_prompt.out" ] &&
        [ ! -s "$_stage/allowed_prompt.err" ]; then
        ok "Codex guard allows unrelated UserPromptSubmit input"
    else
        fail "Codex guard blocks or prints output for unrelated UserPromptSubmit input"
    fi
    _envrc_literal=$(printf "\056envrc")
    _allowed_discussion_prompt=$(printf "{\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"Explain the string %s without reading files.\"}" "$_envrc_literal")
    if _run_codex_guard "$_allowed_discussion_prompt" allowed_discussion_prompt &&
        [ ! -s "$_stage/allowed_discussion_prompt.out" ] &&
        [ ! -s "$_stage/allowed_discussion_prompt.err" ]; then
        ok "Codex guard allows plain-text sensitive basename discussion"
    else
        fail "Codex guard blocks plain-text sensitive basename discussion"
    fi

    _allowed_spaced_ssh_prompt='{"hook_event_name":"UserPromptSubmit","prompt":"Explain ~ / . s s h as plain text."}'
    if _run_codex_guard "$_allowed_spaced_ssh_prompt" allowed_spaced_ssh_prompt &&
        [ ! -s "$_stage/allowed_spaced_ssh_prompt.out" ] &&
        [ ! -s "$_stage/allowed_spaced_ssh_prompt.err" ]; then
        ok "Codex guard allows spaced plain-text SSH directory discussion"
    else
        fail "Codex guard blocks spaced plain-text SSH directory discussion"
    fi

    _allowed_ssh_config_prompt=$(jq -cn --arg path "$_fake_ssh_config" \
        '{hook_event_name:"UserPromptSubmit", prompt:("Read " + $path + " for me.")}')
    if _run_codex_guard "$_allowed_ssh_config_prompt" allowed_ssh_config_prompt &&
        [ ! -s "$_stage/allowed_ssh_config_prompt.out" ] &&
        [ ! -s "$_stage/allowed_ssh_config_prompt.err" ]; then
        ok "Codex guard allows SSH config prompt targets"
    else
        fail "Codex guard blocks SSH config prompt targets"
    fi

    _blocked_ssh_dir_prompt=$(jq -cn --arg path "$_fake_home/.ssh" \
        '{hook_event_name:"UserPromptSubmit", prompt:("List " + $path + " for me.")}')
    if _run_codex_guard "$_blocked_ssh_dir_prompt" blocked_ssh_dir_prompt &&
        jq -e '.decision == "block"' "$_stage/blocked_ssh_dir_prompt.out" >/dev/null &&
        ! grep -F -q "$_fake_home/.ssh" "$_stage/blocked_ssh_dir_prompt.out" &&
        ! grep -F -q "$_fake_key_canary" "$_stage/blocked_ssh_dir_prompt.out"; then
        ok "Codex guard blocks SSH directory prompt targets without echoing path"
    else
        fail "Codex guard does not block SSH directory prompt targets cleanly"
    fi

    _blocked_prompt=$(jq -cn --arg path "$_fake_key" \
        '{hook_event_name:"UserPromptSubmit", prompt:("Read " + $path + " for me.")}')
    if _run_codex_guard "$_blocked_prompt" blocked_prompt &&
        jq -e '.decision == "block"' "$_stage/blocked_prompt.out" >/dev/null &&
        ! grep -F -q "$_fake_key" "$_stage/blocked_prompt.out" &&
        ! grep -F -q "$_fake_key_canary" "$_stage/blocked_prompt.out"; then
        ok "Codex guard blocks fake SSH-key prompt without echoing path or canary"
    else
        fail "Codex guard does not block fake SSH-key prompt cleanly"
    fi

    _allowed_ssh_config_bash=$(jq -cn --arg path "$_fake_ssh_config" \
        '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:("sed -n 1,20p " + $path)}}')
    if _run_codex_guard "$_allowed_ssh_config_bash" allowed_ssh_config_bash &&
        [ ! -s "$_stage/allowed_ssh_config_bash.out" ] &&
        [ ! -s "$_stage/allowed_ssh_config_bash.err" ]; then
        ok "Codex guard allows SSH config Bash targets"
    else
        fail "Codex guard blocks SSH config Bash targets"
    fi

    _allowed_ssh_include_mcp=$(jq -cn --arg path "$_fake_ssh_include" \
        '{hook_event_name:"PreToolUse", tool_name:"mcp__filesystem__read_file", tool_input:{path:$path}}')
    if _run_codex_guard "$_allowed_ssh_include_mcp" allowed_ssh_include_mcp &&
        [ ! -s "$_stage/allowed_ssh_include_mcp.out" ] &&
        [ ! -s "$_stage/allowed_ssh_include_mcp.err" ]; then
        ok "Codex guard allows SSH config.d MCP targets"
    else
        fail "Codex guard blocks SSH config.d MCP targets"
    fi

    _allowed_ssh_config_dir_bash=$(jq -cn --arg path "$_fake_home/.ssh/config.d" \
        '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:("mkdir -p " + $path)}}')
    if _run_codex_guard "$_allowed_ssh_config_dir_bash" allowed_ssh_config_dir_bash &&
        [ ! -s "$_stage/allowed_ssh_config_dir_bash.out" ] &&
        [ ! -s "$_stage/allowed_ssh_config_dir_bash.err" ]; then
        ok "Codex guard allows SSH config.d directory targets"
    else
        fail "Codex guard blocks SSH config.d directory targets"
    fi

    _allowed_pub_mcp=$(jq -cn --arg path "$_fake_pub_key" \
        '{hook_event_name:"PreToolUse", tool_name:"mcp__filesystem__read_file", tool_input:{path:$path}}')
    if _run_codex_guard "$_allowed_pub_mcp" allowed_pub_mcp &&
        [ ! -s "$_stage/allowed_pub_mcp.out" ] &&
        [ ! -s "$_stage/allowed_pub_mcp.err" ]; then
        ok "Codex guard allows SSH public-key MCP targets"
    else
        fail "Codex guard blocks SSH public-key MCP targets"
    fi

    _blocked_bash=$(jq -cn --arg path "$_fake_env" \
        '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:("sed -n 1,20p " + $path)}}')
    if _run_codex_guard "$_blocked_bash" blocked_bash &&
        jq -e '.hookSpecificOutput.permissionDecision == "deny"' "$_stage/blocked_bash.out" >/dev/null &&
        ! grep -F -q "$_fake_env" "$_stage/blocked_bash.out" &&
        ! grep -F -q "$_fake_env_canary" "$_stage/blocked_bash.out"; then
        ok "Codex guard denies fake env Bash calls without echoing path or canary"
    else
        fail "Codex guard does not deny fake env Bash access cleanly"
    fi

    _blocked_mcp=$(jq -cn --arg path "$_fake_env" \
        '{hook_event_name:"PreToolUse", tool_name:"mcp__filesystem__read_file", tool_input:{path:$path}}')
    if _run_codex_guard "$_blocked_mcp" blocked_mcp &&
        jq -e '.hookSpecificOutput.permissionDecision == "deny"' "$_stage/blocked_mcp.out" >/dev/null &&
        ! grep -F -q "$_fake_env" "$_stage/blocked_mcp.out" &&
        ! grep -F -q "$_fake_env_canary" "$_stage/blocked_mcp.out"; then
        ok "Codex guard denies fake env MCP calls without echoing path or canary"
    else
        fail "Codex guard does not deny fake env MCP access cleanly"
    fi

    _allowed_search_pattern=$(printf "{\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rg -n %s tests\"}}" "$_envrc_literal")
    if _run_codex_guard "$_allowed_search_pattern" allowed_search_pattern &&
        [ ! -s "$_stage/allowed_search_pattern.out" ] &&
        [ ! -s "$_stage/allowed_search_pattern.err" ]; then
        ok "Codex guard allows sensitive basename search patterns"
    else
        fail "Codex guard blocks sensitive basename search patterns"
    fi

    _allowed_tool='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status --short"}}'
    if _run_codex_guard "$_allowed_tool" allowed_tool &&
        [ ! -s "$_stage/allowed_tool.out" ] &&
        [ ! -s "$_stage/allowed_tool.err" ]; then
        ok "Codex guard allows unrelated PreToolUse input"
    else
        fail "Codex guard blocks or prints output for unrelated PreToolUse input"
    fi

    rm -rf "$_stage"
else
    fail "missing Codex sensitive-file guard hook"
fi

if grep -q 'dot_codex/hooks/executable_sensitive-file-guard.sh' "$SCRIPT_DIR/bin/dotfiles" &&
    grep -q 'run_onchange_after_63-codex-security.sh.tmpl' "$SCRIPT_DIR/bin/dotfiles"; then
    ok "dotfiles test includes the Codex sensitive-file guard and merge script"
else
    fail "dotfiles test does not include the Codex sensitive-file guard and merge script"
fi

if command -v chezmoi >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 &&
    [ -f "$_codex_security_tmpl" ]; then
    _stage="$SCRIPT_DIR/.tmp-dotfiles-codex-security.$$"
    mkdir -p "$_stage"
    _rendered="$_stage/run.sh"
    if chezmoi execute-template -S "$SCRIPT_DIR/home" <"$_codex_security_tmpl" >"$_rendered" 2>/dev/null; then
        chmod +x "$_rendered"

        _h1="$_stage/h1"
        mkdir -p "$_h1/.codex" "$_h1/.ssh"
        printf '%s\n' \
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakePublicKeyOnly dotfiles-test' \
            >"$_h1/.ssh/id_ed25519.pub"
        if HOME="$_h1" "$_rendered" >/dev/null 2>&1 &&
            grep -q 'hooks = true' "$_h1/.codex/config.toml" &&
            ! grep -q 'codex_hooks' "$_h1/.codex/config.toml" &&
            grep -q 'default_permissions = "dotfiles-sensitive"' "$_h1/.codex/config.toml" &&
            grep -F -q '":root" = "read"' "$_h1/.codex/config.toml" &&
            grep -F -q '":tmpdir" = "write"' "$_h1/.codex/config.toml" &&
            grep -F -q '"/tmp" = "write"' "$_h1/.codex/config.toml" &&
            grep -F -q "\"$_h1/.ssh\" = \"none\"" "$_h1/.codex/config.toml" &&
            grep -F -q "\"$_h1/.ssh/config\" = \"write\"" "$_h1/.codex/config.toml" &&
            grep -F -q "\"$_h1/.ssh/config.d\" = \"write\"" "$_h1/.codex/config.toml" &&
            grep -F -q "\"$_h1/.ssh/id_ed25519.pub\" = \"read\"" "$_h1/.codex/config.toml" &&
            ! grep -F -q "\"$_h1/.ssh/*.pub\" = \"read\"" "$_h1/.codex/config.toml" &&
            grep -F -q '".env" = "none"' "$_h1/.codex/config.toml" &&
            jq -e '.hooks.UserPromptSubmit[]?.hooks[]?.command | endswith("/.codex/hooks/sensitive-file-guard.sh")' \
                "$_h1/.codex/hooks.json" >/dev/null &&
            jq -e '.hooks.PreToolUse[]? |
                select(.matcher == "Bash|Read|Glob|Grep|apply_patch|Edit|Write|mcp__.*") |
                .hooks[]?.command | endswith("/.codex/hooks/sensitive-file-guard.sh")' \
                "$_h1/.codex/hooks.json" >/dev/null; then
            ok "Codex security merge creates config permissions and hook settings"
        else
            fail "Codex security merge did not create expected config or hook settings"
        fi

        _h2="$_stage/h2"
        mkdir -p "$_h2/.codex"
        printf '%s\n' \
            'model = "gpt-5.5"' \
            '[features]' \
            'goals = true' \
            'codex_hooks = false' \
            >"$_h2/.codex/config.toml"
        printf '%s\n' \
            '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/bin/true"}]}]}}' \
            >"$_h2/.codex/hooks.json"
        if HOME="$_h2" "$_rendered" >/dev/null 2>&1 &&
            grep -q 'model = "gpt-5.5"' "$_h2/.codex/config.toml" &&
            grep -q 'goals = true' "$_h2/.codex/config.toml" &&
            grep -q 'hooks = true' "$_h2/.codex/config.toml" &&
            ! grep -q 'codex_hooks' "$_h2/.codex/config.toml" &&
            jq -e '.hooks.Stop[]?.hooks[]?.command == "/bin/true"' "$_h2/.codex/hooks.json" >/dev/null &&
            jq -e '.hooks.UserPromptSubmit[]?.hooks[]?.command | endswith("/.codex/hooks/sensitive-file-guard.sh")' \
                "$_h2/.codex/hooks.json" >/dev/null; then
            ok "Codex security merge preserves unrelated config and hook settings"
        else
            fail "Codex security merge disturbed unrelated config or hook settings"
        fi

        _h3="$_stage/h3"
        mkdir -p "$_h3/.codex"
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _cfg_mt1=$(stat -c %Y "$_h3/.codex/config.toml" 2>/dev/null ||
            stat -f %m "$_h3/.codex/config.toml" 2>/dev/null)
        _hooks_mt1=$(stat -c %Y "$_h3/.codex/hooks.json" 2>/dev/null ||
            stat -f %m "$_h3/.codex/hooks.json" 2>/dev/null)
        sleep 1
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _cfg_mt2=$(stat -c %Y "$_h3/.codex/config.toml" 2>/dev/null ||
            stat -f %m "$_h3/.codex/config.toml" 2>/dev/null)
        _hooks_mt2=$(stat -c %Y "$_h3/.codex/hooks.json" 2>/dev/null ||
            stat -f %m "$_h3/.codex/hooks.json" 2>/dev/null)
        if [ "$_cfg_mt1" = "$_cfg_mt2" ] && [ "$_hooks_mt1" = "$_hooks_mt2" ]; then
            ok "Codex security merge is idempotent"
        else
            fail "Codex security merge rewrote already-current files"
        fi
    else
        fail "could not render run_onchange_after_63-codex-security.sh.tmpl"
    fi
    rm -rf "$_stage"
else
    echo "  chezmoi/jq/template missing — skipping Codex security merge behavioural checks"
fi
echo ""

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

# ── .editorconfig ──────────────────────────────────────────────────────────
echo "[editorconfig]"
_ec="$SCRIPT_DIR/.editorconfig"
if grep -q '^root *= *true' "$_ec"; then
    ok ".editorconfig declares root = true"
else
    fail ".editorconfig does not declare root = true"
fi
# POSIX sh in this repo uses 4 spaces.  Must appear within some [*.sh*] section.
if awk '
    /^\[/                                 { section = $0 }
    section ~ /\.sh/ && /indent_size *= *4/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_ec"; then
    ok ".editorconfig sets POSIX sh to 4-space indent"
else
    fail ".editorconfig does not set POSIX sh to 4-space indent"
fi
# chezmoi script templates inherit the POSIX sh rule.
if awk '
    /^\[/                                      { section = $0 }
    section ~ /sh\.tmpl/ && /indent_size *= *4/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_ec"; then
    ok ".editorconfig sets *.sh.tmpl to 4-space indent"
else
    fail ".editorconfig does not set *.sh.tmpl to 4-space indent"
fi
if grep -q '^end_of_line *= *lf' "$_ec"; then
    ok ".editorconfig normalises line endings to LF"
else
    fail ".editorconfig does not normalise line endings to LF"
fi
echo ""

# ── .gitattributes ─────────────────────────────────────────────────────────
echo "[gitattributes]"
_ga="$SCRIPT_DIR/.gitattributes"
if grep -qE '^\* +text=auto +eol=lf' "$_ga"; then
    ok ".gitattributes normalises all text to LF"
else
    fail ".gitattributes does not normalise text to LF"
fi
if grep -qE 'encrypted_\* +binary' "$_ga"; then
    ok ".gitattributes marks chezmoi encrypted_* files as binary"
else
    fail ".gitattributes does not mark encrypted_* files as binary"
fi
if grep -qE '\*\.sh\.tmpl +linguist-language=Shell' "$_ga"; then
    ok ".gitattributes hints linguist that *.sh.tmpl is Shell"
else
    fail ".gitattributes does not hint linguist for *.sh.tmpl"
fi
echo ""

# ── .gitignore ─────────────────────────────────────────────────────────────
echo "[gitignore]"
_gi="$SCRIPT_DIR/.gitignore"
if grep -q 'key\.txt' "$_gi"; then
    ok ".gitignore blocks age private keys (key.txt)"
else
    fail ".gitignore does not block age private keys"
fi
if grep -qE '(^|/)\*\.age' "$_gi"; then
    ok ".gitignore blocks *.age identity files"
else
    fail ".gitignore does not block *.age identity files"
fi
if grep -q 'credentials\.env' "$_gi"; then
    ok ".gitignore blocks plaintext credentials.env"
else
    fail ".gitignore does not block plaintext credentials.env"
fi
if grep -q '\.DS_Store' "$_gi"; then
    ok ".gitignore hides .DS_Store"
else
    fail ".gitignore does not hide .DS_Store"
fi
if grep -q 'config\.symlink' "$_gi"; then
    fail ".gitignore still references the legacy config.symlink/ layout"
else
    ok ".gitignore no longer references the legacy config.symlink/ layout"
fi
echo ""

# ── Claude statusline wireup behaviour ─────────────────────────────────────
echo "[claude statusline wireup]"
_tmpl="$SCRIPT_DIR/home/run_onchange_after_60-claude-statusline.sh.tmpl"
if command -v chezmoi >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    _stage="${TMPDIR:-/tmp}/dotfiles-statusline.$$"
    mkdir -p "$_stage"
    _rendered="$_stage/run.sh"
    if chezmoi execute-template -S "$SCRIPT_DIR/home" <"$_tmpl" >"$_rendered" 2>/dev/null; then
        chmod +x "$_rendered"

        # Scenario 1: no settings.json — should be created with just statusLine.
        _h1="$_stage/h1"
        mkdir -p "$_h1/.claude"
        if HOME="$_h1" "$_rendered" >/dev/null 2>&1 &&
            [ -f "$_h1/.claude/settings.json" ] &&
            [ "$(jq -r '.statusLine.type' "$_h1/.claude/settings.json")" = "command" ] &&
            [ "$(jq -r '.statusLine.padding' "$_h1/.claude/settings.json")" = "0" ] &&
            jq -e '.statusLine.command | endswith("/.claude/statusline-command.sh")' \
                "$_h1/.claude/settings.json" >/dev/null; then
            ok "creates settings.json with statusLine when missing"
        else
            fail "did not create settings.json with statusLine when missing"
        fi

        # Scenario 2: existing settings.json with unrelated fields — must be preserved.
        _h2="$_stage/h2"
        mkdir -p "$_h2/.claude"
        printf '%s\n' '{"env":{"FOO":"bar"},"hooks":{"SessionStart":[]},"autoMemoryEnabled":false}' \
            >"$_h2/.claude/settings.json"
        if HOME="$_h2" "$_rendered" >/dev/null 2>&1 &&
            [ "$(jq -r '.env.FOO' "$_h2/.claude/settings.json")" = "bar" ] &&
            [ "$(jq -r '.autoMemoryEnabled' "$_h2/.claude/settings.json")" = "false" ] &&
            jq -e '.hooks.SessionStart | type == "array"' "$_h2/.claude/settings.json" >/dev/null &&
            [ "$(jq -r '.statusLine.type' "$_h2/.claude/settings.json")" = "command" ]; then
            ok "preserves unrelated keys when merging statusLine"
        else
            fail "did not preserve unrelated keys when merging statusLine"
        fi

        # Scenario 3: idempotency — second run leaves the file untouched.
        _h3="$_stage/h3"
        mkdir -p "$_h3/.claude"
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _mt1=$(stat -c %Y "$_h3/.claude/settings.json" 2>/dev/null ||
            stat -f %m "$_h3/.claude/settings.json" 2>/dev/null)
        sleep 1
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _mt2=$(stat -c %Y "$_h3/.claude/settings.json" 2>/dev/null ||
            stat -f %m "$_h3/.claude/settings.json" 2>/dev/null)
        if [ "$_mt1" = "$_mt2" ]; then
            ok "idempotent: second run does not rewrite settings.json"
        else
            fail "idempotent: second run rewrote settings.json (mtime changed)"
        fi
    else
        fail "could not render run_onchange_after_60-claude-statusline.sh.tmpl"
    fi
    rm -rf "$_stage"
else
    echo "  chezmoi or jq missing — skipping behavioural checks"
fi
echo ""

# ── Neovim system-wide install (spec 005) ─────────────────────────────────
echo "[neovim system install]"
_nvtmpl="$SCRIPT_DIR/home/run_onchange_after_15-neovim.sh.tmpl"
if [ -f "$_nvtmpl" ]; then
    # Pinned version must be v0.11+ (the >= 0.11 floor doctor enforces).
    # Match v0.11 / v0.12 / ... / v0.99 / v1.x — anything below v0.11 fails.
    if grep -qE '^NVIM_VERSION="v(0\.(1[1-9]|[2-9][0-9])|[1-9][0-9]*\.[0-9]+)' "$_nvtmpl"; then
        ok "pins NVIM_VERSION to v0.11+"
    else
        fail "does not pin NVIM_VERSION to v0.11+"
    fi
    # Download URL must be the upstream GitHub release path.
    if grep -q 'github.com/neovim/neovim/releases/download/' "$_nvtmpl"; then
        ok "downloads from upstream github.com/neovim/neovim/releases/download/"
    else
        fail "does not download from upstream GitHub releases"
    fi
    # Install path: /opt/nvim-<os>-<arch>
    if grep -q '/opt/nvim-' "$_nvtmpl"; then
        ok "installs under /opt/nvim-"
    else
        fail "does not install under /opt/nvim-"
    fi
    # /opt may not exist on minimal systems — must be created (as root/sudo)
    # before extracting into it (spec 044).
    if grep -qE 'need_sudo mkdir -p /opt$' "$_nvtmpl"; then
        ok "creates /opt before extracting (spec 044)"
    else
        fail "does not create /opt before extracting (spec 044)"
    fi
    # Symlink into /usr/local/bin/nvim so root / sudoedit / cron can see it.
    if grep -q '/usr/local/bin/nvim' "$_nvtmpl"; then
        ok "symlinks /usr/local/bin/nvim"
    else
        fail "does not symlink /usr/local/bin/nvim"
    fi
    # OS dispatch must cover both Linux and Darwin.
    if grep -q 'Linux)' "$_nvtmpl" && grep -q 'Darwin)' "$_nvtmpl"; then
        ok "dispatches on Linux and Darwin"
    else
        fail "does not dispatch on both Linux and Darwin"
    fi
    # Arch dispatch must cover x86_64 and arm64/aarch64.
    if grep -qE 'x86_64|amd64' "$_nvtmpl" && grep -qE 'arm64|aarch64' "$_nvtmpl"; then
        ok "dispatches on x86_64 and arm64/aarch64"
    else
        fail "does not dispatch on both x86_64 and arm64"
    fi
    # Idempotency: must short-circuit when installed version matches the pin.
    if grep -q 'NVIM_VERSION' "$_nvtmpl" &&
        grep -qE 'already installed|skipping' "$_nvtmpl"; then
        ok "has idempotency short-circuit keyed on installed version"
    else
        fail "missing idempotency short-circuit"
    fi
    # Best-effort cleanup of the now-retired mise-managed neovim.
    if grep -q 'mise uninstall neovim' "$_nvtmpl"; then
        ok "cleans up stale mise-managed neovim"
    else
        fail "does not clean up stale mise-managed neovim"
    fi
    # Curl invocation must be hardened (-fL with TLS).
    if grep -qE 'curl -[a-zA-Z]*f[a-zA-Z]*L|curl -fL' "$_nvtmpl"; then
        ok "curl invocation uses -fL"
    else
        fail "curl invocation does not use -fL"
    fi
fi
# README.md must record the new install path and drop neovim from the
# mise-tools row.
if grep -qE '^\| \*\*Dev tools\*\*.*neovim' "$SCRIPT_DIR/README.md"; then
    fail "README.md still lists neovim under the mise Dev tools row"
else
    ok "README.md no longer lists neovim under mise"
fi
if grep -q '/opt/nvim-' "$SCRIPT_DIR/README.md"; then
    ok "README.md documents the /opt/nvim- install path"
else
    fail "README.md does not document the /opt/nvim- install path"
fi
echo ""

# ── Spec 009: per-platform BROWSER in dot_zshenv.tmpl ───────────────────────
echo "[spec 009 — browser per platform]"
_zshenvtmpl="$SCRIPT_DIR/home/dot_zshenv.tmpl"
# The plain dot_zshenv must be gone — the template replaces it.
if [ -e "$SCRIPT_DIR/home/dot_zshenv" ]; then
    fail "home/dot_zshenv still exists (should be renamed to dot_zshenv.tmpl)"
else
    ok "home/dot_zshenv no longer exists as a plain file"
fi
if [ -f "$_zshenvtmpl" ]; then
    # brave.exe hard-code must be gone.
    if grep -q 'BROWSER="brave.exe"' "$_zshenvtmpl"; then
        fail "dot_zshenv.tmpl still hard-codes BROWSER=brave.exe"
    else
        ok "dot_zshenv.tmpl no longer hard-codes brave.exe"
    fi
    # All three dispatch outputs must be present as literal strings.
    for target in 'BROWSER="wslview"' 'BROWSER="open"' 'BROWSER="xdg-open"'; do
        if grep -qF "$target" "$_zshenvtmpl"; then
            ok "dot_zshenv.tmpl contains $target"
        else
            fail "dot_zshenv.tmpl missing $target"
        fi
    done
    # WSL detection must use `contains "microsoft" (lower ...)` so
    # kernel osrelease casing does not matter.
    if grep -q 'contains "microsoft" (lower .chezmoi.kernel.osrelease)' "$_zshenvtmpl"; then
        ok "dot_zshenv.tmpl guards WSL branch on lower-cased kernel osrelease"
    else
        fail "dot_zshenv.tmpl does not guard WSL branch on lower-cased kernel osrelease"
    fi
    # Render the template on the current host and check it parses and
    # emits exactly one BROWSER= line.
    if command -v chezmoi >/dev/null 2>&1; then
        _zsrendered="${TMPDIR:-/tmp}/dotfiles-zshenv.$$"
        if chezmoi execute-template -S "$SCRIPT_DIR/home" <"$_zshenvtmpl" >"$_zsrendered" 2>/dev/null; then
            ok "dot_zshenv.tmpl renders"
            if sh -n "$_zsrendered" 2>/dev/null; then
                ok "rendered dot_zshenv parses under sh -n"
            else
                fail "rendered dot_zshenv does not parse under sh -n"
                sh -n "$_zsrendered" >&2 || true
            fi
            _brcount="$(grep -c '^export BROWSER=' "$_zsrendered" 2>/dev/null || echo 0)"
            if [ "$_brcount" = "1" ]; then
                ok "rendered dot_zshenv emits exactly one BROWSER= line"
            else
                fail "rendered dot_zshenv emits $_brcount BROWSER= lines (expected 1 on linux/darwin)"
                cat "$_zsrendered" >&2 || true
            fi
        else
            fail "dot_zshenv.tmpl failed to render"
            chezmoi execute-template -S "$SCRIPT_DIR/home" <"$_zshenvtmpl" >&2 || true
        fi
        rm -f "$_zsrendered"
    else
        echo "  chezmoi not installed — skipping render check"
    fi
fi
echo ""

# ── Spec 009: wslu on Debian WSL ────────────────────────────────────────────
echo "[spec 009 — wslu on Debian WSL]"
_syspkgs="$SCRIPT_DIR/home/run_once_before_10-system-packages.sh.tmpl"
if [ -f "$_syspkgs" ]; then
    if grep -q 'wslu' "$_syspkgs"; then
        ok "system-packages references wslu"
    else
        fail "system-packages does not reference wslu"
    fi
    if grep -q 'grep -qi microsoft /proc/version' "$_syspkgs"; then
        ok "system-packages guards wslu install on /proc/version microsoft"
    else
        fail "system-packages does not guard wslu install on /proc/version microsoft"
    fi
fi
echo ""

# ── Spec 026: terminal auth unlock prompts ─────────────────────────────────
echo "[spec 026 — terminal auth unlock prompts]"
_authmod="$SCRIPT_DIR/home/dot_config/dotfiles/modules/auth-unlock.zsh"
_sshagent="$SCRIPT_DIR/home/dot_config/dotfiles/modules/ssh-agent.zsh"
_pinentry="$SCRIPT_DIR/home/dot_config/dotfiles/bin/executable_pinentry-auto"
_gpgagent="$SCRIPT_DIR/home/private_dot_gnupg/gpg-agent.conf.tmpl"
_gpgagent_auth="$SCRIPT_DIR/home/run_onchange_after_42-gpg-agent-auth.sh.tmpl"
_sshconfig_auth="$SCRIPT_DIR/home/run_onchange_after_41-ssh-config-auth.sh.tmpl"
_zshrc="$SCRIPT_DIR/home/dot_zshrc"
_dotfiles_cli="$SCRIPT_DIR/bin/dotfiles"
_readme="$SCRIPT_DIR/README.md"

if [ -f "$_authmod" ]; then
    if grep -q 'export GPG_TTY=' "$_authmod" &&
        grep -q 'gpg-connect-agent updatestartuptty /bye' "$_authmod"; then
        ok "auth-unlock exports GPG_TTY and refreshes gpg-agent TTY"
    else
        fail "auth-unlock does not wire GPG_TTY and gpg-agent TTY refresh"
    fi
    if grep -q 'SSH_ASKPASS_REQUIRE="prefer"' "$_authmod" &&
        grep -q 'SSH_ASKPASS=' "$_authmod"; then
        ok "auth-unlock configures SSH askpass prefer mode"
    else
        fail "auth-unlock does not configure SSH askpass prefer mode"
    fi
    if grep -q 'SUDO_ASKPASS=' "$_authmod"; then
        ok "auth-unlock configures sudo askpass"
    else
        fail "auth-unlock does not configure sudo askpass"
    fi
    if grep -q 'DISPLAY' "$_authmod" && grep -q 'WAYLAND_DISPLAY' "$_authmod"; then
        ok "auth-unlock detects graphical sessions"
    else
        fail "auth-unlock does not check graphical session variables"
    fi
fi

if [ -f "$_sshagent" ]; then
    if grep -q 'DOTFILES_SSH_AGENT_TTL' "$_sshagent" &&
        grep -q 'ssh-agent -t "$_ssh_agent_ttl" -s' "$_sshagent"; then
        ok "ssh-agent starts with bounded identity lifetime"
    else
        fail "ssh-agent does not start with a bounded identity lifetime"
    fi
fi

if [ -f "$_pinentry" ]; then
    if sh -n "$_pinentry" 2>/dev/null; then
        ok "pinentry-auto parses under sh -n"
    else
        fail "pinentry-auto does not parse under sh -n"
        sh -n "$_pinentry" >&2 || true
    fi
    if grep -q 'pinentry-gnome3' "$_pinentry" &&
        grep -q 'pinentry-curses' "$_pinentry" &&
        grep -q 'pinentry-tty' "$_pinentry"; then
        ok "pinentry-auto includes GUI and terminal fallback candidates"
    else
        fail "pinentry-auto is missing GUI or terminal pinentry candidates"
    fi
fi

if [ -f "$_gpgagent" ]; then
    if grep -q '^default-cache-ttl 3600$' "$_gpgagent" &&
        grep -q '^max-cache-ttl 14400$' "$_gpgagent"; then
        ok "gpg-agent config sets one-hour/four-hour cache TTLs"
    else
        fail "gpg-agent config does not set expected cache TTLs"
    fi
    if grep -q 'pinentry-program {{ .chezmoi.homeDir }}/.config/dotfiles/bin/pinentry-auto' "$_gpgagent"; then
        ok "gpg-agent config uses managed pinentry-auto"
    else
        fail "gpg-agent config does not use managed pinentry-auto"
    fi
fi

if [ -f "$_gpgagent_auth" ]; then
    if grep -q 'private_dot_gnupg/gpg-agent.conf.tmpl' "$_gpgagent_auth" &&
        grep -q 'gpgconf --kill gpg-agent' "$_gpgagent_auth"; then
        ok "gpg-agent auth script restarts agent after config changes"
    else
        fail "gpg-agent auth script does not restart agent after config changes"
    fi
fi

if [ -f "$_sshconfig_auth" ]; then
    if grep -q 'BEGIN dotfiles auth unlock' "$_sshconfig_auth" &&
        grep -q '^Host \*$' "$_sshconfig_auth" &&
        grep -q '^[[:space:]]*AddKeysToAgent yes$' "$_sshconfig_auth"; then
        ok "ssh config auth script appends managed AddKeysToAgent block"
    else
        fail "ssh config auth script does not append managed AddKeysToAgent block"
    fi
    if grep -q 'cat >>"\$ssh_config"' "$_sshconfig_auth" &&
        grep -q 'chmod 600 "\$ssh_config"' "$_sshconfig_auth"; then
        ok "ssh config auth script preserves existing config and fixes mode"
    else
        fail "ssh config auth script does not preserve existing config and mode"
    fi
fi

if [ -f "$_zshrc" ]; then
    if awk '
        /source "\$DOTFILES\/modules\/ssh-agent.zsh"/ { ssh_agent = NR }
        /source "\$DOTFILES\/modules\/auth-unlock.zsh"/ { auth_unlock = NR }
        /p10k-instant-prompt/ && !p10k { p10k = NR }
        END {
            exit(ssh_agent && auth_unlock && p10k && ssh_agent < auth_unlock && auth_unlock < p10k ? 0 : 1)
        }
    ' "$_zshrc"; then
        ok "dot_zshrc sources auth-unlock after ssh-agent and before p10k"
    else
        fail "dot_zshrc does not source auth-unlock in the required order"
    fi
fi

if [ -f "$_syspkgs" ]; then
    for pkg in pinentry-gnome3 pinentry-curses ssh-askpass-gnome pinentry-mac ksshaskpass openssh-askpass; do
        if grep -q "$pkg" "$_syspkgs"; then
            ok "system packages reference $pkg"
        else
            fail "system packages do not reference $pkg"
        fi
    done
fi

if grep -q 'auth-unlock.zsh' "$_dotfiles_cli" &&
    grep -q 'executable_pinentry-auto' "$_dotfiles_cli"; then
    ok "dotfiles test parses auth-unlock and pinentry-auto"
else
    fail "dotfiles test does not parse auth-unlock and pinentry-auto"
fi

if grep -q 'pinentry-auto' "$_readme" &&
    grep -q 'four hour' "$_readme" &&
    grep -q 'SSH_ASKPASS_REQUIRE=prefer' "$_readme"; then
    ok "README documents terminal auth unlock behavior"
else
    fail "README does not document terminal auth unlock behavior"
fi
echo ""

# ── Spec 010: Claude Code sandbox packages ─────────────────────────────────
# Every Linux distro branch must install bubblewrap + socat so Claude
# Code's /sandbox works without a manual apt/pacman/dnf step. macOS uses
# built-in Seatbelt, so install_darwin must NOT list either package.
echo "[spec 010 — claude sandbox packages]"
_syspkgs="$SCRIPT_DIR/home/run_once_before_10-system-packages.sh.tmpl"
if [ -f "$_syspkgs" ]; then
    for fn in install_debian install_arch install_fedora; do
        for pkg in bubblewrap socat; do
            if awk -v fn="$fn" -v pkg="$pkg" '
                $0 ~ "^" fn "\\(\\) *\\{" { in_fn=1; next }
                in_fn && /^\}/            { in_fn=0 }
                in_fn {
                    pat = "(^|[[:space:]])" pkg "([[:space:]]|$)"
                    if ($0 ~ pat) found=1
                }
                END { exit(found ? 0 : 1) }
            ' "$_syspkgs"; then
                ok "$fn installs $pkg"
            else
                fail "$fn does not install $pkg"
            fi
        done
    done
    # install_darwin must stay untouched — Seatbelt is built in.
    for pkg in bubblewrap socat; do
        if awk -v pkg="$pkg" '
            /^install_darwin\(\) *\{/ { in_fn=1; next }
            in_fn && /^\}/            { in_fn=0 }
            in_fn {
                pat = "(^|[[:space:]])" pkg "([[:space:]]|$)"
                if ($0 ~ pat) found=1
            }
            END { exit(found ? 0 : 1) }
        ' "$_syspkgs"; then
            fail "install_darwin references $pkg (macOS uses Seatbelt — should be absent)"
        else
            ok "install_darwin does not reference $pkg"
        fi
    done
fi
echo ""

# ── Spec 012: direnv integration ───────────────────────────────────────────
# direnv must ship as a mise-managed tool (checked above), carry a global
# config with load_dotenv = true so bare `.env` files activate alongside
# `.envrc`, and be wired into dot_zshrc AFTER `mise activate zsh` so the
# direnv hook sees the mise-shimmed direnv binary on PATH at eval time.
echo "[spec 012 — direnv integration]"
_direnvcfg="$SCRIPT_DIR/home/dot_config/direnv/direnv.toml"
if [ -f "$_direnvcfg" ]; then
    ok "home/dot_config/direnv/direnv.toml exists"
    # Must declare [global] load_dotenv = true so `.env` files activate
    # without requiring an accompanying `.envrc`.  Scan line-by-line,
    # tracking the current section header, so a stray `load_dotenv = true`
    # outside `[global]` does not satisfy the check.
    if awk '
        /^\[/                                       { section = $0 }
        section == "[global]" && /^[[:space:]]*load_dotenv[[:space:]]*=[[:space:]]*true/ { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "$_direnvcfg"; then
        ok "direnv.toml sets [global] load_dotenv = true"
    else
        fail "direnv.toml does not set [global] load_dotenv = true"
    fi
else
    fail "home/dot_config/direnv/direnv.toml missing"
fi
# dot_zshrc must eval the zsh hook so direnv runs on every cd.
if grep -q 'direnv hook zsh' "$_zshrc"; then
    ok "dot_zshrc evals direnv hook zsh"
else
    fail "dot_zshrc does not eval direnv hook zsh"
fi
# The eval must be guarded on `command -v direnv` so a machine without
# direnv installed (pre-`dotfiles install`) still loads a working shell.
if awk '
    /direnv hook zsh/ && prev ~ /command -v direnv/ { found=1 }
    { prev = $0 }
    END { exit(found ? 0 : 1) }
' "$_zshrc"; then
    ok "direnv hook is guarded by command -v direnv"
else
    fail "direnv hook is not guarded by command -v direnv"
fi
# Ordering: direnv hook must come AFTER `mise activate zsh` so direnv
# inherits mise's PATH (including the mise-shimmed direnv binary itself).
# Same NR-comparison pattern as the spec-007 PATH-prepend check above.
if awk '
    /mise activate zsh/    { mise_line = NR }
    /direnv hook zsh/      { direnv_line = NR }
    END { exit(mise_line && direnv_line && direnv_line > mise_line ? 0 : 1) }
' "$_zshrc"; then
    ok "direnv hook runs after mise activate in dot_zshrc"
else
    fail "direnv hook does not run after mise activate in dot_zshrc (spec 012)"
fi
echo ""

# ── Spec 038: p10k + direnv startup handshake ─────────────────────────────
echo "[spec 038 — p10k direnv startup]"
if grep -qF '(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv export zsh)"' "$_zshrc"; then
    ok "dot_zshrc exports direnv env before p10k using emulate zsh"
else
    fail "dot_zshrc does not run the p10k-safe direnv export"
fi
if awk '
    /direnv export zsh/             { export_line = NR }
    /p10k-instant-prompt/ && !p10k { p10k = NR }
    /direnv hook zsh/               { hook_line = NR }
    END { exit(export_line && p10k && hook_line && export_line < p10k && p10k < hook_line ? 0 : 1) }
' "$_zshrc"; then
    ok "direnv export runs before p10k and direnv hook stays after p10k"
else
    fail "direnv export/hook ordering conflicts with p10k startup"
fi
echo ""

# ── Statusline module locations (spec 021 refactor) ────────────────────────
# After spec 021 the helpers live under home/dot_claude/statusline/{core,data,
# width,items,layout}.sh; the entrypoint is a thin orchestrator. The
# spec-013/014/017/018 structural assertions retarget to those modules.
_sl_main="$SCRIPT_DIR/home/dot_claude/executable_statusline-command.sh"
_sl_core="$SCRIPT_DIR/home/dot_claude/statusline/core.sh"
_sl_data="$SCRIPT_DIR/home/dot_claude/statusline/data.sh"
_sl_items="$SCRIPT_DIR/home/dot_claude/statusline/items.sh"
_sl_layout="$SCRIPT_DIR/home/dot_claude/statusline/layout.sh"
_sl_width="$SCRIPT_DIR/home/dot_claude/statusline/width.sh"

# ── Claude Code statusline long-name truncation (spec 013) ─────────────────
echo "[claude statusline (spec 013)]"
if [ ! -f "$_sl_core" ] || [ ! -f "$_sl_items" ]; then
    fail "missing statusline modules (spec 021 refactor)"
else
    # Structural: truncate_name helper is defined in core.sh
    if grep -q '^truncate_name()' "$_sl_core"; then
        ok "truncate_name helper is defined (core.sh)"
    else
        fail "truncate_name helper is missing from core.sh"
    fi

    # Structural: 🪵 worktree segment applies truncate_name with 28 cap
    if grep -q 'truncate_name "\${git_worktree}" 28' "$_sl_items"; then
        ok "worktree slug is truncated to 28 chars (items.sh)"
    else
        fail "worktree slug is not truncated to 28 chars in items.sh"
    fi

    # Structural: 🌿 branch segment (non-worktree path) truncates to 30 chars
    if grep -q 'truncate_name "\${git_branch}" 30' "$_sl_items"; then
        ok "branch name is truncated to 30 chars outside a worktree (items.sh)"
    else
        fail "branch name is not truncated to 30 chars outside a worktree"
    fi

    # Structural: worktree-branch dedup suppresses redundant branch display
    if grep -q '"\${git_branch}" == "worktree-\${git_worktree}"' "$_sl_items" &&
        grep -q 'branch_redundant=1' "$_sl_items"; then
        ok "branch display is suppressed when it encodes the worktree slug"
    else
        fail "branch display is not suppressed for worktree-encoded branches"
    fi

    # Behavioural: run truncate_name under bash with below/above-threshold inputs
    if command -v bash >/dev/null 2>&1; then
        _fn=$(awk '/^truncate_name\(\) \{/,/^}/' "$_sl_core")
        _below=$(bash -c "$_fn"'
            truncate_name "short" 10' 2>/dev/null)
        _above=$(bash -c "$_fn"'
            truncate_name "abcdefghijklmnop" 5' 2>/dev/null)
        if [ "$_below" = "short" ]; then
            ok "truncate_name preserves name below threshold"
        else
            fail "truncate_name mangled name below threshold: '$_below'"
        fi
        if [ "$_above" = "abcde…" ]; then
            ok "truncate_name truncates + appends … above threshold"
        else
            fail "truncate_name did not truncate correctly: '$_above'"
        fi
    else
        ok "skipped behavioural truncate_name check (bash not available)"
    fi
fi
echo ""

# ── Claude Code statusline ahead/behind counters (spec 014) ───────────────
echo "[claude statusline (spec 014)]"
if [ ! -f "$_sl_data" ] || [ ! -f "$_sl_items" ]; then
    fail "missing statusline modules (spec 014 checks skipped)"
else
    # Structural: collect_git_info must initialise git_ahead and git_behind
    if grep -q 'git_ahead=0' "$_sl_data" && grep -q 'git_behind=0' "$_sl_data"; then
        ok "collect_git_info initialises git_ahead and git_behind (data.sh)"
    else
        fail "collect_git_info does not initialise git_ahead / git_behind"
    fi

    # Structural: ahead/behind populated via rev-list or equivalent
    if grep -qE 'rev-list|@\{u\}|@\{upstream\}' "$_sl_data"; then
        ok "collect_git_info uses git rev-list / upstream ref for ahead/behind"
    else
        fail "collect_git_info does not use git rev-list / upstream ref"
    fi

    # Structural: ↑ (ahead) indicator rendered by an item emitter
    if grep -q '↑' "$_sl_items"; then
        ok "items.sh contains ↑ (ahead) indicator"
    else
        fail "items.sh missing ↑ (ahead) indicator"
    fi

    # Structural: ↓ (behind) indicator rendered by an item emitter
    if grep -q '↓' "$_sl_items"; then
        ok "items.sh contains ↓ (behind) indicator"
    else
        fail "items.sh missing ↓ (behind) indicator"
    fi
fi
echo ""

# ── Spec 016: git clear-gone alias ─────────────────────────────────────────
# `git clear-gone` should be a one-shot post-PR cleanup: refresh remote
# tracking refs with `git fetch --all --prune`, list local branches whose
# upstream is `[gone]` via `git for-each-ref`, then force-delete each one
# with `git branch -D` in a portable shell loop (no xargs -r).
echo "[spec 016 — git clear-gone alias]"
_gitcfg="$SCRIPT_DIR/home/dot_gitconfig"
if [ -f "$_gitcfg" ]; then
    if awk '
        /^\[/                                                         { section = $0 }
        section == "[alias]" && /^[[:space:]]*clear-gone[[:space:]]*=/ { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "$_gitcfg"; then
        ok "dot_gitconfig declares clear-gone under [alias]"
    else
        fail "dot_gitconfig does not declare clear-gone under [alias]"
    fi
    if grep -q 'fetch --all --prune' "$_gitcfg"; then
        ok "clear-gone refreshes remotes via git fetch --all --prune"
    else
        fail "clear-gone does not run git fetch --all --prune"
    fi
    if grep -q 'for-each-ref' "$_gitcfg"; then
        ok "clear-gone enumerates branches via git for-each-ref"
    else
        fail "clear-gone does not use git for-each-ref"
    fi
    if grep -qF '[gone]' "$_gitcfg"; then
        ok "clear-gone filters on the [gone] upstream-track marker"
    else
        fail "clear-gone does not filter on [gone]"
    fi
    if grep -q 'git branch -D' "$_gitcfg"; then
        ok "clear-gone force-deletes via git branch -D"
    else
        fail "clear-gone does not force-delete via git branch -D"
    fi
fi
echo ""

# ── Claude Code statusline API duration display (spec 017) ───────────────
echo "[claude statusline (spec 017)]"
if [ ! -f "$_sl_core" ] || [ ! -f "$_sl_data" ] || [ ! -f "$_sl_items" ]; then
    fail "missing statusline modules (spec 017 checks skipped)"
else
    # Structural: extract_fields reads cost.total_api_duration_ms
    if grep -q 'total_api_duration_ms=.*cost.total_api_duration_ms' "$_sl_data"; then
        ok "extract_fields reads cost.total_api_duration_ms (data.sh)"
    else
        fail "extract_fields does not read cost.total_api_duration_ms"
    fi

    # Structural: format_api_duration helper is defined
    if grep -q '^format_api_duration()' "$_sl_core"; then
        ok "format_api_duration helper is defined (core.sh)"
    else
        fail "format_api_duration helper is missing from core.sh"
    fi

    # Structural: an item emitter renders the ⏱ marker with api_duration_str
    if grep -q '⏱ \${api_duration_str}' "$_sl_items"; then
        ok "items.sh renders the ⏱ api-duration segment"
    else
        fail "items.sh does not render the ⏱ api-duration segment"
    fi

    # Structural: entrypoint computes api_duration_str via format_api_duration
    if grep -q 'api_duration_str=.*format_api_duration' "$_sl_main"; then
        ok "entrypoint computes api_duration_str via format_api_duration"
    else
        fail "entrypoint does not compute api_duration_str"
    fi

    # Behavioural: format_api_duration produces expected strings
    if command -v bash >/dev/null 2>&1; then
        _fn=$(awk '/^format_api_duration\(\) \{/,/^}/' "$_sl_core")
        _zero=$(bash -c "$_fn"'
            format_api_duration 0' 2>/dev/null)
        _secs=$(bash -c "$_fn"'
            format_api_duration 42000' 2>/dev/null)
        _min=$(bash -c "$_fn"'
            format_api_duration 154321' 2>/dev/null)
        _hr=$(bash -c "$_fn"'
            format_api_duration 3792000' 2>/dev/null)
        if [ -z "$_zero" ]; then
            ok "format_api_duration returns empty for 0 ms"
        else
            fail "format_api_duration returned '$_zero' for 0 ms"
        fi
        if [ "$_secs" = "42s" ]; then
            ok "format_api_duration formats sub-minute as Xs"
        else
            fail "format_api_duration returned '$_secs' for 42000 ms"
        fi
        if [ "$_min" = "2m 34s" ]; then
            ok "format_api_duration formats minutes as Xm Ys"
        else
            fail "format_api_duration returned '$_min' for 154321 ms"
        fi
        if [ "$_hr" = "1h 3m 12s" ]; then
            ok "format_api_duration formats hours as Xh Ym Zs"
        else
            fail "format_api_duration returned '$_hr' for 3792000 ms"
        fi
    else
        ok "skipped behavioural format_api_duration check (bash not available)"
    fi
fi
echo ""

# ── Claude Code statusline session-mins via file birth time (spec 018) ──
echo "[claude statusline (spec 018)]"
if [ ! -f "$_sl_data" ]; then
    fail "missing statusline data module (spec 018 checks skipped)"
else
    # Structural: file_btime helper is defined
    if grep -q '^file_btime()' "$_sl_data"; then
        ok "file_btime helper is defined (data.sh)"
    else
        fail "file_btime helper is missing from data.sh"
    fi

    # Structural: file_btime tries %W (Linux) or %B (macOS/BSD)
    if grep -q 'stat -c %W' "$_sl_data" && grep -q 'stat -f %B' "$_sl_data"; then
        ok "file_btime queries birth time via stat -c %W / -f %B"
    else
        fail "file_btime does not query birth time via stat"
    fi

    # Structural: compute_session_mins uses file_btime (not only mtime)
    if awk '/^compute_session_mins\(\) \{/,/^}/' "$_sl_data" |
        grep -q 'file_btime'; then
        ok "compute_session_mins uses file_btime"
    else
        fail "compute_session_mins does not use file_btime"
    fi

    # Structural: JSONL timestamp fallback is wired
    if awk '/^file_btime\(\) \{/,/^}/' "$_sl_data" |
        grep -q '\.timestamp'; then
        ok "file_btime falls back to first-line JSONL timestamp"
    else
        fail "file_btime has no JSONL timestamp fallback"
    fi
fi
echo ""

# ── Spec 020: shell autocomplete wiring ────────────────────────────────────
# Three layers: system PM packages (bash-completion, zsh-syntax-highlighting,
# zsh-autosuggestions in every distro branch); user-scope mise-tool completion
# generation via run_onchange_after_16-completions.sh.tmpl; dot_zshrc wires
# in the completions module before omz, bashcompinit after, and the two
# zsh-* plugins at end of file.
echo "[spec 020 — shell completions]"

check_exists "home/dot_config/dotfiles/modules/completions.zsh"
check_exists "home/run_onchange_after_16-completions.sh.tmpl"
check_sh_parse "home/run_onchange_after_16-completions.sh.tmpl"
check_no_bashisms "home/run_onchange_after_16-completions.sh.tmpl"

_complgen="$SCRIPT_DIR/home/run_onchange_after_16-completions.sh.tmpl"
if [ -f "$_complgen" ]; then
    # Hash directive ties re-runs to the mise manifest (mirrors spec 010's
    # mise-config-hash pattern in run_onchange_after_10-mise-install).
    if grep -q '^# completion-config-hash:' "$_complgen"; then
        ok "completions generator declares completion-config-hash"
    else
        fail "completions generator missing completion-config-hash directive"
    fi
fi

_zshrc="$SCRIPT_DIR/home/dot_zshrc"
if [ -f "$_zshrc" ]; then
    if grep -qF 'source "$DOTFILES/modules/completions.zsh"' "$_zshrc"; then
        ok "dot_zshrc sources completions module"
    else
        fail "dot_zshrc does not source $DOTFILES/modules/completions.zsh"
    fi

    # bashcompinit must run after compinit (which omz invokes).  We do not
    # assert the line order here; the structural check is "called at all".
    if grep -q 'bashcompinit' "$_zshrc"; then
        ok "dot_zshrc invokes bashcompinit"
    else
        fail "dot_zshrc does not invoke bashcompinit"
    fi

    if grep -q 'zsh-autosuggestions\.zsh' "$_zshrc"; then
        ok "dot_zshrc sources zsh-autosuggestions.zsh"
    else
        fail "dot_zshrc does not source zsh-autosuggestions.zsh"
    fi

    if grep -q 'zsh-syntax-highlighting\.zsh' "$_zshrc"; then
        ok "dot_zshrc sources zsh-syntax-highlighting.zsh"
    else
        fail "dot_zshrc does not source zsh-syntax-highlighting.zsh"
    fi
fi

_complmod="$SCRIPT_DIR/home/dot_config/dotfiles/modules/completions.zsh"
if [ -f "$_complmod" ]; then
    # Module must guard on the user-scope dir existing so a fresh-bootstrap
    # shell (run_onchange not yet executed) sources cleanly.
    if grep -q '\.local/share/zsh/completions' "$_complmod"; then
        ok "completions module references user-scope dir"
    else
        fail "completions module missing user-scope dir reference"
    fi
    # Prepend (user-scope wins over system-scope per spec).
    if grep -qE 'fpath=\(.*completions.*\$fpath\)' "$_complmod"; then
        ok "completions module prepends user dir to fpath"
    else
        fail "completions module does not prepend user dir to fpath"
    fi
fi

# System-packages: bash-completion + zsh-syntax-highlighting + zsh-autosuggestions
# in every distro branch.  Reuses the awk pattern from spec 010.
if [ -f "$_syspkgs" ]; then
    for fn in install_debian install_arch install_fedora install_darwin; do
        for pkg in bash-completion zsh-syntax-highlighting zsh-autosuggestions; do
            # macOS uses bash-completion@2 instead of bash-completion.
            search="$pkg"
            if [ "$fn" = "install_darwin" ] && [ "$pkg" = "bash-completion" ]; then
                search='bash-completion@2'
            fi
            if awk -v fn="$fn" -v pkg="$search" '
                $0 ~ "^" fn "\\(\\) *\\{" { in_fn=1; next }
                in_fn && /^\}/            { in_fn=0 }
                in_fn {
                    pat = "(^|[[:space:]])" pkg "([[:space:]]|$)"
                    if ($0 ~ pat) found=1
                }
                END { exit(found ? 0 : 1) }
            ' "$_syspkgs"; then
                ok "$fn installs $search"
            else
                fail "$fn does not install $search"
            fi
        done
    done
fi
echo ""

# ── Claude Code statusline responsive layout (spec 021) ─────────────────
# Verify the item-list + packer architecture: five module files exist and
# parse, the entrypoint sources them, and the renderer adapts to terminal
# width via CLAUDE_STATUSLINE_COLS without exceeding 5 lines.
echo "[claude statusline (spec 021)]"

_sldir="$SCRIPT_DIR/home/dot_claude/statusline"

# Module files exist + parse cleanly under bash
for mod in core data width items layout; do
    f="$_sldir/$mod.sh"
    if [ -f "$f" ]; then
        ok "module exists: statusline/$mod.sh"
    else
        fail "module missing: statusline/$mod.sh"
    fi
done

if command -v bash >/dev/null 2>&1; then
    for mod in core data width items layout; do
        f="$_sldir/$mod.sh"
        if [ -f "$f" ] && bash -n "$f" 2>/dev/null; then
            ok "bash -n: statusline/$mod.sh"
        else
            fail "bash -n: statusline/$mod.sh (syntax error or missing)"
        fi
    done
fi

# Width module: detect_columns + escape hatch + 80 fallback
if [ -f "$_sl_width" ]; then
    if grep -q '^detect_columns()' "$_sl_width"; then
        ok "detect_columns is defined in width.sh"
    else
        fail "detect_columns is not defined in width.sh"
    fi
    if grep -q 'CLAUDE_STATUSLINE_COLS' "$_sl_width"; then
        ok "detect_columns honours CLAUDE_STATUSLINE_COLS escape hatch"
    else
        fail "detect_columns does not honour CLAUDE_STATUSLINE_COLS"
    fi
    if grep -qE '(^|[^0-9])80([^0-9]|$)' "$_sl_width"; then
        ok "detect_columns falls back to literal 80"
    else
        fail "detect_columns has no 80 fallback literal"
    fi
fi

# Items module: _ITEMS array + item_push helper
if [ -f "$_sl_items" ]; then
    if grep -q '_ITEMS' "$_sl_items" && grep -q '^item_push()' "$_sl_items"; then
        ok "_ITEMS array + item_push helper defined in items.sh"
    else
        fail "_ITEMS / item_push missing from items.sh"
    fi
fi

# Layout module: layout_pack + layout_render + max_lines = 5
if [ -f "$_sl_layout" ]; then
    if grep -q '^layout_pack()' "$_sl_layout" &&
        grep -q '^layout_render()' "$_sl_layout"; then
        ok "layout_pack + layout_render defined in layout.sh"
    else
        fail "layout_pack / layout_render missing from layout.sh"
    fi
    if grep -qE 'max_lines.*=.*5|=5.*max_lines|MAX_LINES.*=.*5' "$_sl_layout"; then
        ok "layout module references max_lines = 5"
    else
        fail "layout module has no max_lines = 5 reference"
    fi
fi

# Entrypoint sources all 5 modules
if [ -f "$_sl_main" ]; then
    _missing_src=""
    for mod in core data width items layout; do
        if grep -q "statusline/$mod.sh" "$_sl_main"; then
            :
        else
            _missing_src="$_missing_src $mod"
        fi
    done
    if [ -z "$_missing_src" ]; then
        ok "entrypoint sources all 5 statusline modules"
    else
        fail "entrypoint missing source for:$_missing_src"
    fi
fi

# Behavioural: rendered output respects terminal width
if command -v bash >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 &&
    [ -f "$_sl_main" ]; then
    _fixture='{
      "model": {"id":"claude-opus-4-7","display_name":"Opus"},
      "workspace": {"current_dir":"/tmp","project_dir":"/tmp"},
      "cwd": "/tmp",
      "session_id": "spec021-test",
      "transcript_path": "/dev/null",
      "version": "2.1.90",
      "cost": {"total_cost_usd":0.123,"total_duration_ms":60000,"total_api_duration_ms":15000},
      "context_window": {
        "total_input_tokens": 12000,
        "total_output_tokens": 3000,
        "used_percentage": 25,
        "current_usage": {
          "input_tokens": 1000,
          "output_tokens": 200,
          "cache_creation_input_tokens": 500,
          "cache_read_input_tokens": 4000
        }
      },
      "rate_limits": {
        "five_hour": {"used_percentage":42,"resets_at":9999999999},
        "seven_day": {"used_percentage":13,"resets_at":9999999999}
      }
    }'

    # Width 300 → 1 line, contains model and Context (everything fits)
    _out300=$(printf '%s' "$_fixture" |
        env -u COLUMNS CLAUDE_STATUSLINE_COLS=300 \
            bash "$_sl_main" 2>/dev/null)
    _lines300=$(printf '%s\n' "$_out300" | grep -c .)
    if [ "$_lines300" -eq 1 ] &&
        printf '%s' "$_out300" | grep -q 'Opus' &&
        printf '%s' "$_out300" | grep -q 'Context'; then
        ok "width=300 renders 1 line containing model + Context"
    else
        fail "width=300 produced $_lines300 line(s); expected 1 with Opus+Context"
    fi

    # Width 80 → 2-5 lines, model + Context + Weekly all present
    _out80=$(printf '%s' "$_fixture" |
        env -u COLUMNS CLAUDE_STATUSLINE_COLS=80 \
            bash "$_sl_main" 2>/dev/null)
    _lines80=$(printf '%s\n' "$_out80" | grep -c .)
    if [ "$_lines80" -ge 2 ] && [ "$_lines80" -le 5 ] &&
        printf '%s' "$_out80" | grep -q 'Opus' &&
        printf '%s' "$_out80" | grep -q 'Context'; then
        ok "width=80 renders $_lines80 line(s) containing model + Context"
    else
        fail "width=80 produced $_lines80 line(s); expected 2-5 with Opus+Context"
    fi

    # Width 40 → ≤ 5 lines, model still present, P2 Weekly bar dropped
    _out40=$(printf '%s' "$_fixture" |
        env -u COLUMNS CLAUDE_STATUSLINE_COLS=40 \
            bash "$_sl_main" 2>/dev/null)
    _lines40=$(printf '%s\n' "$_out40" | grep -c .)
    if [ "$_lines40" -ge 1 ] && [ "$_lines40" -le 5 ] &&
        printf '%s' "$_out40" | grep -q 'Opus'; then
        ok "width=40 renders $_lines40 line(s) within max-5 cap, model present"
    else
        fail "width=40 produced $_lines40 line(s); expected 1-5 with Opus"
    fi
    if printf '%s' "$_out40" | grep -q 'Weekly'; then
        fail "width=40 still shows P2 'Weekly' bar (drop logic broken)"
    else
        ok "width=40 drops the P2 Weekly bar"
    fi
fi
echo ""

# ── Claude Code statusline /proc-based width detection (spec 022) ──────
# detect_columns must recover the real terminal width when the subprocess
# has no controlling terminal, by walking /proc/<ppid>/fd/* to find the
# parent's pty and running stty size against it. Also: the </dev/tty probe
# must not leak its open-failure error to stderr.
echo "[claude statusline (spec 022)]"

if [ ! -f "$_sl_width" ]; then
    fail "missing statusline width module (spec 022 checks skipped)"
else
    if grep -q '^detect_columns_from_proc()' "$_sl_width"; then
        ok "detect_columns_from_proc helper is defined"
    else
        fail "detect_columns_from_proc helper is missing"
    fi

    if grep -q '/proc/' "$_sl_width"; then
        ok "width.sh references /proc/ (parent-pty walk)"
    else
        fail "width.sh does not reference /proc/"
    fi

    if grep -q '/dev/pts/' "$_sl_width"; then
        ok "width.sh matches against /dev/pts/* paths"
    else
        fail "width.sh does not match /dev/pts/*"
    fi

    # The </dev/tty probe must wrap stderr suppression around the redirect.
    if grep -qE '\{[^}]*</dev/tty[^}]*;[[:space:]]*\}[[:space:]]*2>/dev/null' "$_sl_width"; then
        ok "</dev/tty probe is wrapped in a {...} 2>/dev/null group"
    else
        fail "</dev/tty probe still leaks open-failure to stderr"
    fi

    if grep -qE '(^|[^0-9])80([^0-9]|$)' "$_sl_width"; then
        ok "detect_columns still falls back to literal 80"
    else
        fail "detect_columns has no 80 fallback literal"
    fi

    # Behavioural: running the entrypoint with no ctty must not leak the
    # /dev/tty open error to stderr.
    if command -v bash >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 &&
        [ -f "$_sl_main" ]; then
        _stderr=$(printf '{}' |
            env -u COLUMNS -u CLAUDE_STATUSLINE_COLS \
                bash "$_sl_main" 2>&1 >/dev/null)
        if printf '%s' "$_stderr" | grep -q 'No such device'; then
            fail "statusline still leaks /dev/tty open error: $_stderr"
        else
            ok "statusline does not leak /dev/tty open error to stderr"
        fi
    fi
fi
echo ""

# ── Claude Code statusline extra session-state items (spec 023) ────────────
echo "[claude statusline (spec 023)]"

if [ ! -f "$_sl_data" ] || [ ! -f "$_sl_items" ]; then
    fail "missing statusline modules (spec 023 checks skipped)"
else
    # Structural: extract_fields reads the four new payload fields
    for field in '.effort.level' '.output_style.name' '.thinking.enabled' '.vim.mode'; do
        if grep -qF "${field}" "$_sl_data"; then
            ok "extract_fields reads ${field} (data.sh)"
        else
            fail "extract_fields does not read ${field} (data.sh)"
        fi
    done

    # Structural: four new emit_* functions are defined
    for fn in emit_effort emit_output_style emit_thinking emit_vim_mode; do
        if grep -q "^${fn}()" "$_sl_items"; then
            ok "${fn} is defined (items.sh)"
        else
            fail "${fn} is missing from items.sh"
        fi
    done

    # Structural: emit_effort references the ✦ symbol
    if grep -q '✦' "$_sl_items"; then
        ok "emit_effort references the ✦ symbol (items.sh)"
    else
        fail "emit_effort does not reference the ✦ symbol (items.sh)"
    fi

    # Structural: emit_vim_mode references VIM: prefix
    if grep -q 'VIM:' "$_sl_items"; then
        ok "emit_vim_mode references VIM: prefix (items.sh)"
    else
        fail "emit_vim_mode does not reference VIM: prefix (items.sh)"
    fi

    # Structural: emit_all calls all four new emitters
    for fn in emit_effort emit_output_style emit_thinking emit_vim_mode; do
        if awk '/^emit_all\(\)/,/^}/' "$_sl_items" | grep -q "${fn}"; then
            ok "emit_all calls ${fn}"
        else
            fail "emit_all does not call ${fn}"
        fi
    done

    # Behavioural: all four fields visible when all are set and width=300
    if command -v bash >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 &&
        [ -f "$_sl_main" ]; then
        _fix_full='{
          "model": {"id":"claude-opus-4-7","display_name":"Opus"},
          "workspace": {"current_dir":"/tmp","project_dir":"/tmp"},
          "cwd": "/tmp",
          "session_id": "spec023-test-full",
          "transcript_path": "/dev/null",
          "version": "2.1.90",
          "effort": {"level":"xhigh"},
          "output_style": {"name":"Explanatory"},
          "thinking": {"enabled":true},
          "vim": {"mode":"INSERT"},
          "context_window": {
            "total_input_tokens": 5000,
            "total_output_tokens": 1000,
            "used_percentage": 10
          }
        }'
        _out_full=$(printf '%s' "$_fix_full" |
            env -u COLUMNS CLAUDE_STATUSLINE_COLS=300 \
                bash "$_sl_main" 2>/dev/null)
        _out_full_plain=$(printf '%s' "$_out_full" | sed 's/\x1b\[[0-9;]*m//g')
        for want in 'effort:xhigh' 'Explanatory' 'thinking' 'VIM:INSERT'; do
            if printf '%s' "$_out_full_plain" | grep -qF "$want"; then
                ok "width=300 full fixture: output contains '$want'"
            else
                fail "width=300 full fixture: output missing '$want' (got: $(printf '%s' "$_out_full_plain" | tr -s ' '))"
            fi
        done

        # effort:low present, thinking and VIM absent when not set
        _fix_partial='{
          "model": {"id":"claude-opus-4-7","display_name":"Opus"},
          "workspace": {"current_dir":"/tmp","project_dir":"/tmp"},
          "cwd": "/tmp",
          "session_id": "spec023-test-partial",
          "transcript_path": "/dev/null",
          "version": "2.1.90",
          "effort": {"level":"low"},
          "thinking": {"enabled":false},
          "context_window": {
            "total_input_tokens": 5000,
            "total_output_tokens": 1000,
            "used_percentage": 10
          }
        }'
        _out_partial=$(printf '%s' "$_fix_partial" |
            env -u COLUMNS CLAUDE_STATUSLINE_COLS=300 \
                bash "$_sl_main" 2>/dev/null)
        _out_partial_plain=$(printf '%s' "$_out_partial" | sed 's/\x1b\[[0-9;]*m//g')
        if printf '%s' "$_out_partial_plain" | grep -qF 'effort:low'; then
            ok "partial fixture: output contains 'effort:low'"
        else
            fail "partial fixture: output missing 'effort:low'"
        fi
        if printf '%s' "$_out_partial_plain" | grep -q 'thinking'; then
            fail "partial fixture: output unexpectedly contains 'thinking' when disabled"
        else
            ok "partial fixture: 'thinking' absent when thinking.enabled=false"
        fi
        if printf '%s' "$_out_partial_plain" | grep -q 'VIM:'; then
            fail "partial fixture: output unexpectedly contains 'VIM:' when vim absent"
        else
            ok "partial fixture: 'VIM:' absent when vim field missing"
        fi

        # output_style=default must be suppressed
        _fix_default_style='{
          "model": {"id":"claude-opus-4-7","display_name":"Opus"},
          "workspace": {"current_dir":"/tmp","project_dir":"/tmp"},
          "cwd": "/tmp",
          "session_id": "spec023-test-default-style",
          "transcript_path": "/dev/null",
          "version": "2.1.90",
          "output_style": {"name":"default"},
          "context_window": {
            "total_input_tokens": 5000,
            "total_output_tokens": 1000,
            "used_percentage": 10
          }
        }'
        _out_dstyle=$(printf '%s' "$_fix_default_style" |
            env -u COLUMNS CLAUDE_STATUSLINE_COLS=300 \
                bash "$_sl_main" 2>/dev/null)
        # The style emitter must be silent for "default"; we check the
        # ✎ glyph does not appear (it is only used by emit_output_style).
        if printf '%s' "$_out_dstyle" | grep -q '✎'; then
            fail "default style: output unexpectedly shows ✎ for output_style=default"
        else
            ok "default style: ✎ suppressed when output_style.name=default"
        fi
    fi
fi
echo ""

# ── Summary ─────────────────────────────────────────────────────────────────
echo "Result: $OK ok, $FAIL failed"
[ "$FAIL" -eq 0 ]
