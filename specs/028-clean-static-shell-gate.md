# 028 - Keep the shell static gate clean

## Intent

ShellCheck and shfmt are now part of the mise-managed development toolchain, so
`dotfiles test` should be a reliable local gate when those tools are installed.
The static gate must fail on real lint or formatting drift, not on intentional
literal-match smoke tests or cross-file statusline globals that ShellCheck
cannot infer from dynamic sourcing.

## Acceptance criteria

- `bin/dotfiles test` passes when mise-provided `shellcheck`, `shfmt`, and
  `bats` are available.
- Intentional literal grep patterns in `tests/test_smoke.sh` are documented for
  ShellCheck instead of rewritten into less readable escaping.
- The Claude statusline scripts document their cross-file global contract for
  ShellCheck without changing runtime behaviour.
- Shell scripts covered by `bin/dotfiles test` are formatted according to the
  repository's `shfmt -d` gate.

## Out of scope

- Changing the list of files included in the static gate.
- Adding a separate pre-commit lint runner.
- Reworking the Claude statusline module architecture.
- Pinning ShellCheck or shfmt versions.

## Affected files

- `specs/028-clean-static-shell-gate.md`
- `tests/test_smoke.sh`
- `home/dot_claude/executable_statusline-command.sh`
- `home/dot_claude/statusline/core.sh`
- `home/dot_claude/statusline/data.sh`
- `home/dot_claude/statusline/width.sh`
- `home/dot_claude/statusline/items.sh`
- `home/dot_claude/statusline/layout.sh`
- Any other shell file touched only by `shfmt`
