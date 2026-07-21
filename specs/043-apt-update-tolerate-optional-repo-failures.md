# 043 — apt update tolerates optional-repo failures

## Intent

Spec 024 made `apt-get update` failures during bootstrap visible and
diagnosable by adding `-o "APT::Update::Error-Mode=any"`. In practice this
option makes bootstrap treat *any* configured apt source's failure as fatal,
including third-party/vendor repos (e.g. a browser vendor's apt repo with a
stale or missing GPG key) that bootstrap does not need anything from. When
the core distro archive (main/security/updates) refreshes successfully but
an unrelated optional repo fails signature verification, apt itself only
warns and falls back to the previous cached index for that repo — yet
bootstrap dies anyway, because `Error-Mode=any` promotes that warning to a
hard error.

This spec corrects that: bootstrap must only fail the apt index refresh step
when apt itself cannot proceed (e.g. `apt-get update` returns non-zero
because the reachable/required indexes could not be fetched), not merely
because one optional configured source emitted a warning.

## Acceptance criteria

- Debian-family bootstrap continues to log an explicit apt index refresh
  message before running `apt-get update` (unchanged from spec 024).
- The apt update command continues to run without quiet mode, and continues
  to configure `Acquire::http::Timeout`, `Acquire::https::Timeout`, and
  `Acquire::Retries` so a dead repository does not hang bootstrap
  indefinitely (unchanged from spec 024).
- The apt update command no longer passes
  `-o "APT::Update::Error-Mode=any"`. Bootstrap relies on apt's default
  error handling: a failing optional/third-party source that apt can work
  around (cached index, other sources still fresh) is a warning, not a
  bootstrap-ending failure.
- If `apt-get update` exits non-zero (apt's own default failure condition),
  bootstrap still exits with the existing diagnostic that tells the user to
  inspect the repository URL printed above and disable the broken apt
  source before rerunning (unchanged from spec 024).
- The implementation remains POSIX `sh` compatible.

## Out of scope

- Automatically editing, disabling, or removing user-managed apt sources.
- Special-casing any specific vendor or PPA hostname.
- Changing package-manager behaviour for non-Debian-family distributions.

## Affected files

- `specs/043-apt-update-tolerate-optional-repo-failures.md` (new)
- `bootstrap.sh` — drop `APT::Update::Error-Mode=any` from `apt_get_update()`.
- `tests/test_smoke.sh` — update the spec-024 apt diagnostics assertions to
  assert the flag's absence instead of its presence.
