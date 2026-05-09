# 025 - Bats-based shell test framework

## Intent

The repository currently has a single POSIX `sh` smoke test script that checks
structure, syntax, and selected regression assertions. That script is valuable
because it has almost no dependencies, but it has become too broad for TDD: new
behavioural checks are mixed into one long file, failures are less local, and
fixture-heavy shell behaviour is hard to express.

Adopt Bats-core as the primary behaviour/integration test runner for shell
scripts while keeping the existing POSIX smoke script as the zero-dependency
baseline. Bats is actively maintained and provides a simple command-oriented
test model that is easy for both humans and AI agents to use during
Spec -> Test -> Code work.

Bats does not prove POSIX portability because Bats tests execute under Bash.
Portability remains covered by explicit parse/static gates such as `sh -n`,
rendered chezmoi template parsing, `zsh -n`, ShellCheck, and shfmt when those
tools are available.

## Acceptance criteria

- The existing `tests/test_smoke.sh` remains runnable with POSIX `sh` and does
  not require Bats.
- The repository declares Bats as a mise-managed test tool using the `bats`
  registry name.
- The repository contains a Bats suite under `tests/bats/`.
- The `dotfiles` CLI exposes a `test` command that runs the smoke test first,
  runs the Bats suite when `bats` is available, and runs optional static/parse
  gates when their tools are available.
- If `bats` is missing, `dotfiles test` reports the skipped Bats suite without
  failing the zero-dependency smoke path.
- The Bats suite includes at least one executable behavioural test for the
  `dotfiles` CLI.
- README and agent guidance document the new test tiers and explain that Bats
  is the primary behaviour test runner while portability is checked separately.

## Out of scope

- Rewriting all existing smoke assertions into Bats.
- Introducing ShellSpec or another second shell test framework.
- Requiring Bats during first-time bootstrap before mise has installed the
  development toolchain.
- Adding CI configuration.
- Replacing existing chezmoi dry-run checks.

## Affected files

- `specs/025-bats-test-framework.md` (new)
- `tests/test_smoke.sh` - smoke assertions for the Bats test structure and CLI
  wiring.
- `tests/bats/` - new Bats behaviour tests and helpers.
- `home/dot_config/mise/config.toml` - Bats tool declaration.
- `bin/dotfiles` - `test` command and optional gates.
- `README.md` - testing documentation.
- `AGENTS.md` - agent testing guidance.
