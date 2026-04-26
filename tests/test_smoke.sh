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
check_exists ".editorconfig"
check_exists ".gitattributes"
check_exists ".gitignore"
check_exists "bootstrap.sh"
check_exists "bin/dotfiles"
check_exists "README.md"
check_exists "CLAUDE.md"
check_exists "AGENTS.md"
for f in .editorconfig .gitattributes .gitignore; do
    if [ -s "$SCRIPT_DIR/$f" ]; then
        ok "non-empty: $f"
    else
        fail "empty: $f"
    fi
done

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
check_exists "home/dot_zshenv.tmpl"
check_exists "home/dot_gitconfig"
check_exists "home/empty_dot_gitignore"
check_exists "home/empty_dot_tmux.conf"
check_exists "home/dot_config/mise/config.toml"
check_exists "home/dot_config/direnv/direnv.toml"
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
check_exists "home/run_onchange_after_15-neovim.sh.tmpl"
check_exists "home/run_once_after_20-ohmyzsh.sh.tmpl"
check_exists "home/run_once_after_30-nvchad.sh.tmpl"
check_exists "home/run_onchange_after_40-git-hooks.sh.tmpl"
check_exists "home/run_once_after_50-default-shell.sh.tmpl"
check_exists "home/run_onchange_after_60-claude-statusline.sh.tmpl"
check_exists "home/run_onchange_after_61-claude-env.sh.tmpl"
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
# codex (OpenAI Codex CLI) must be declared so every machine ships the
# terminal coding agent alongside Claude Code via mise shims (spec 011 —
# aqua:openai/codex backend pulls the static release binary).
if awk '
    /^\[/                         { section = $0 }
    section == "[tools]" && /^[[:space:]]*codex[[:space:]]*=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$_misecfg"; then
    ok "mise config declares codex under [tools]"
else
    fail "mise config does not declare codex under [tools]"
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
# Fcitx5 must be guarded so machines without it skip the block entirely.
if grep -q 'command -v fcitx5' "$_zprof"; then
    ok "dot_zprofile guards fcitx5 on command -v fcitx5"
else
    fail "dot_zprofile does not guard fcitx5 on command -v fcitx5"
fi
# Daemon must not be relaunched when one is already running.
if grep -q 'pgrep.*fcitx5' "$_zprof"; then
    ok "dot_zprofile checks pgrep before launching fcitx5"
else
    fail "dot_zprofile does not check pgrep before launching fcitx5"
fi
# Typo fix: SDL_IM_MODULE must be fcitx, not icitx.
if grep -q 'SDL_IM_MODULE=icitx' "$_zprof"; then
    fail "dot_zprofile still has SDL_IM_MODULE=icitx typo"
else
    ok "dot_zprofile no longer has SDL_IM_MODULE=icitx typo"
fi
if grep -q 'SDL_IM_MODULE=fcitx' "$_zprof"; then
    ok "dot_zprofile sets SDL_IM_MODULE=fcitx"
else
    fail "dot_zprofile does not set SDL_IM_MODULE=fcitx"
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
    if chezmoi execute-template -S "$SCRIPT_DIR/home" < "$_envtmpl" > "$_rendered" 2>/dev/null; then
        chmod +x "$_rendered"

        # Scenario 1: no settings.json — file is created with env.ENABLE_LSP_TOOL="1".
        _h1="$_stage/h1"
        mkdir -p "$_h1/.claude"
        if HOME="$_h1" "$_rendered" >/dev/null 2>&1 \
           && [ -f "$_h1/.claude/settings.json" ] \
           && [ "$(jq -r '.env.ENABLE_LSP_TOOL' "$_h1/.claude/settings.json")" = "1" ]; then
            ok "creates settings.json with env.ENABLE_LSP_TOOL when missing"
        else
            fail "did not create settings.json with env.ENABLE_LSP_TOOL when missing"
        fi

        # Scenario 2: unrelated env keys and unrelated top-level keys must survive.
        _h2="$_stage/h2"
        mkdir -p "$_h2/.claude"
        printf '%s\n' '{"env":{"FOO":"bar"},"statusLine":{"type":"command","command":"x","padding":0},"autoMemoryEnabled":false}' \
            > "$_h2/.claude/settings.json"
        if HOME="$_h2" "$_rendered" >/dev/null 2>&1 \
           && [ "$(jq -r '.env.FOO'              "$_h2/.claude/settings.json")" = "bar" ] \
           && [ "$(jq -r '.env.ENABLE_LSP_TOOL'  "$_h2/.claude/settings.json")" = "1" ] \
           && [ "$(jq -r '.statusLine.type'      "$_h2/.claude/settings.json")" = "command" ] \
           && [ "$(jq -r '.autoMemoryEnabled'    "$_h2/.claude/settings.json")" = "false" ]; then
            ok "preserves unrelated env and top-level keys when merging ENABLE_LSP_TOOL"
        else
            fail "did not preserve unrelated keys when merging ENABLE_LSP_TOOL"
        fi

        # Scenario 3: idempotency — second run leaves the file untouched.
        _h3="$_stage/h3"
        mkdir -p "$_h3/.claude"
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _mt1=$(stat -c %Y "$_h3/.claude/settings.json" 2>/dev/null \
               || stat -f %m "$_h3/.claude/settings.json" 2>/dev/null)
        sleep 1
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _mt2=$(stat -c %Y "$_h3/.claude/settings.json" 2>/dev/null \
               || stat -f %m "$_h3/.claude/settings.json" 2>/dev/null)
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
    if chezmoi execute-template -S "$SCRIPT_DIR/home" < "$_tmpl" > "$_rendered" 2>/dev/null; then
        chmod +x "$_rendered"

        # Scenario 1: no settings.json — should be created with just statusLine.
        _h1="$_stage/h1"
        mkdir -p "$_h1/.claude"
        if HOME="$_h1" "$_rendered" >/dev/null 2>&1 \
           && [ -f "$_h1/.claude/settings.json" ] \
           && [ "$(jq -r '.statusLine.type'    "$_h1/.claude/settings.json")" = "command" ] \
           && [ "$(jq -r '.statusLine.padding' "$_h1/.claude/settings.json")" = "0" ] \
           && jq -e '.statusLine.command | endswith("/.claude/statusline-command.sh")' \
                  "$_h1/.claude/settings.json" >/dev/null; then
            ok "creates settings.json with statusLine when missing"
        else
            fail "did not create settings.json with statusLine when missing"
        fi

        # Scenario 2: existing settings.json with unrelated fields — must be preserved.
        _h2="$_stage/h2"
        mkdir -p "$_h2/.claude"
        printf '%s\n' '{"env":{"FOO":"bar"},"hooks":{"SessionStart":[]},"autoMemoryEnabled":false}' \
            > "$_h2/.claude/settings.json"
        if HOME="$_h2" "$_rendered" >/dev/null 2>&1 \
           && [ "$(jq -r '.env.FOO'           "$_h2/.claude/settings.json")" = "bar" ] \
           && [ "$(jq -r '.autoMemoryEnabled' "$_h2/.claude/settings.json")" = "false" ] \
           && jq -e '.hooks.SessionStart | type == "array"' "$_h2/.claude/settings.json" >/dev/null \
           && [ "$(jq -r '.statusLine.type'   "$_h2/.claude/settings.json")" = "command" ]; then
            ok "preserves unrelated keys when merging statusLine"
        else
            fail "did not preserve unrelated keys when merging statusLine"
        fi

        # Scenario 3: idempotency — second run leaves the file untouched.
        _h3="$_stage/h3"
        mkdir -p "$_h3/.claude"
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _mt1=$(stat -c %Y "$_h3/.claude/settings.json" 2>/dev/null \
               || stat -f %m "$_h3/.claude/settings.json" 2>/dev/null)
        sleep 1
        HOME="$_h3" "$_rendered" >/dev/null 2>&1
        _mt2=$(stat -c %Y "$_h3/.claude/settings.json" 2>/dev/null \
               || stat -f %m "$_h3/.claude/settings.json" 2>/dev/null)
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
    if grep -q 'NVIM_VERSION' "$_nvtmpl" \
       && grep -qE 'already installed|skipping' "$_nvtmpl"; then
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
        if chezmoi execute-template -S "$SCRIPT_DIR/home" < "$_zshenvtmpl" > "$_zsrendered" 2>/dev/null; then
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
            chezmoi execute-template -S "$SCRIPT_DIR/home" < "$_zshenvtmpl" >&2 || true
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
    if grep -q '"\${git_branch}" == "worktree-\${git_worktree}"' "$_sl_items" \
        && grep -q 'branch_redundant=1' "$_sl_items"; then
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
    if awk '/^compute_session_mins\(\) \{/,/^}/' "$_sl_data" \
        | grep -q 'file_btime'; then
        ok "compute_session_mins uses file_btime"
    else
        fail "compute_session_mins does not use file_btime"
    fi

    # Structural: JSONL timestamp fallback is wired
    if awk '/^file_btime\(\) \{/,/^}/' "$_sl_data" \
        | grep -q '\.timestamp'; then
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
    if grep -q '^layout_pack()' "$_sl_layout" \
       && grep -q '^layout_render()' "$_sl_layout"; then
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
if command -v bash >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 \
        && [ -f "$_sl_main" ]; then
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
    _out300=$(printf '%s' "$_fixture" | \
        env -u COLUMNS CLAUDE_STATUSLINE_COLS=300 \
        bash "$_sl_main" 2>/dev/null)
    _lines300=$(printf '%s\n' "$_out300" | grep -c .)
    if [ "$_lines300" -eq 1 ] \
       && printf '%s' "$_out300" | grep -q 'Opus' \
       && printf '%s' "$_out300" | grep -q 'Context'; then
        ok "width=300 renders 1 line containing model + Context"
    else
        fail "width=300 produced $_lines300 line(s); expected 1 with Opus+Context"
    fi

    # Width 80 → 2-5 lines, model + Context + Weekly all present
    _out80=$(printf '%s' "$_fixture" | \
        env -u COLUMNS CLAUDE_STATUSLINE_COLS=80 \
        bash "$_sl_main" 2>/dev/null)
    _lines80=$(printf '%s\n' "$_out80" | grep -c .)
    if [ "$_lines80" -ge 2 ] && [ "$_lines80" -le 5 ] \
       && printf '%s' "$_out80" | grep -q 'Opus' \
       && printf '%s' "$_out80" | grep -q 'Context'; then
        ok "width=80 renders $_lines80 line(s) containing model + Context"
    else
        fail "width=80 produced $_lines80 line(s); expected 2-5 with Opus+Context"
    fi

    # Width 40 → ≤ 5 lines, model still present, P2 Weekly bar dropped
    _out40=$(printf '%s' "$_fixture" | \
        env -u COLUMNS CLAUDE_STATUSLINE_COLS=40 \
        bash "$_sl_main" 2>/dev/null)
    _lines40=$(printf '%s\n' "$_out40" | grep -c .)
    if [ "$_lines40" -ge 1 ] && [ "$_lines40" -le 5 ] \
       && printf '%s' "$_out40" | grep -q 'Opus'; then
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

# ── Summary ─────────────────────────────────────────────────────────────────
echo "Result: $OK ok, $FAIL failed"
[ "$FAIL" -eq 0 ]
