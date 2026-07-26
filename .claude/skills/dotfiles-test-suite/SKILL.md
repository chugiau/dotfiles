---
name: dotfiles-test-suite
description: How the dotfiles test suites are built and extended — the structure and helpers of tests/test_smoke.sh, how to write a new assertion block that freezes a spec decision, the Bats CLI suite, the Windows smoke suite, and the static gates (sh -n, zsh -n, ShellCheck, shfmt). Load before adding or debugging a test in this repo, or when the suite fails on a file you did not touch.
---

# dotfiles test suite

`dotfiles test` is the local gate. It runs `tests/test_smoke.sh` and then
`bats tests/bats`.

## test_smoke.sh is a decision ledger

This is the part that surprises people. `tests/test_smoke.sh` is POSIX sh with
no dependencies beyond coreutils, and most of it is not testing behavior in the
usual sense — it greps sources, parses scripts, and renders chezmoi templates to
assert that decisions recorded in `specs/` are still true. A change that looks
completely unrelated can fail it, and that is the point: the failure message
tells you which decision you just undid.

The corollary is that when a spec settles something, you add an assertion here
so it stays settled.

`SCRIPT_DIR` is the repo root, not `tests/`, so every path in an assertion is
repo-relative.

## Helpers

- `ok <message>` / `fail <message>` — record a result; `fail` writes to stderr.
- `check_exists <path>` — file or directory presence.
- `check_sh_parse <path>` — `sh -n` parse gate.
- `check_no_bashisms <path>` — POSIX-purity gate for files that must run under
  `sh`.
- `check_git_ignored <path>` / `check_git_visible <path>` — assert the
  `.gitignore` posture, used for the secret-material patterns.

## Adding an assertion block

Blocks are grouped by concern, separated by a `# ── Title ───` rule, opened with
`echo "[title]"`, and closed with a bare `echo ""`. Name the spec in the rule so
the reason survives:

```sh
# ── Feature name (spec NNN) ────────────────────────────────────────────────
echo "[feature name]"
if grep -q 'literal snippet' "$SCRIPT_DIR/home/dot_zshrc"; then
    ok "dot_zshrc still does the thing spec NNN requires"
else
    fail "dot_zshrc no longer does the thing spec NNN requires"
fi
echo ""
```

Two things to keep right:

- The file runs under `set -eu`. A bare failing command aborts the suite instead
  of recording a failure, so guard every probe with `if`, or append
  `|| true` where you only want the output.
- Many assertions grep for literal `$...` snippets, which is why the file
  carries a top-level `# shellcheck disable=SC2016`. Keep those patterns in
  single quotes.

For a template, render it before asserting rather than grepping the `.tmpl`
source, so the test checks what the machine will actually get.

## The other suites

- `bats tests/bats` — behavior tests for the `dotfiles` CLI in
  `tests/bats/dotfiles_cli.bats`. Bats runs under Bash, so Bash-only syntax is
  fine here and nowhere else.
- `pwsh -NoProfile -File bin/dotfiles.ps1 test` runs `tests/windows_smoke.ps1`
  on native Windows; it skips the POSIX and Bats checks when `sh` or `bats` are
  not installed.

## Static gates

Pair the suites with the linters that match the file: `sh -n` for POSIX scripts,
`zsh -n` for zsh files, ShellCheck for both, and shfmt for formatting. Rendered
template output is worth passing through the same gates — that is how a broken
template gets caught before an apply.

## When to skip

Documentation-only edits do not need a run unless they change command names,
file paths, or documented test expectations — several assertions grep the
Markdown files themselves.
