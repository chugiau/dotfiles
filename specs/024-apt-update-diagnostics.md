# 024 — apt update diagnostics during bootstrap

## Intent

The bootstrap script currently runs `apt-get update -qq` for Debian-family
systems. When a configured repository is slow or unavailable, especially an
external PPA such as `ppa.launchpadcontent.net`, the command can appear to
hang with no useful context. Users cannot tell whether bootstrap is still
working, waiting on a network endpoint, or stuck.

This spec makes the apt index refresh visible and bounded enough that a
broken repository is reported as the likely cause instead of leaving the
terminal silent.

## Acceptance criteria

- Debian-family bootstrap logs an explicit apt index refresh message before
  running `apt-get update`.
- The apt update command is not run with quiet mode; repository progress and
  failing URLs must remain visible.
- The apt update command configures apt acquire timeouts and retry limits so
  a dead repository does not wait indefinitely at the network layer.
- If the apt update command fails, bootstrap exits with a diagnostic that
  tells the user to inspect the repository URL printed above and disable the
  broken apt source before rerunning.
- The implementation remains POSIX `sh` compatible.

## Out of scope

- Automatically editing or disabling user-managed apt sources.
- Special-casing Launchpad or any specific PPA hostname.
- Changing package-manager behaviour for non-Debian-family distributions.

## Affected files

- `specs/024-apt-update-diagnostics.md` (new)
- `bootstrap.sh` — Debian-family apt update logging, timeout, retry, and
  failure diagnostic.
- `tests/test_smoke.sh` — smoke assertions for the bootstrap apt update
  behaviour.
