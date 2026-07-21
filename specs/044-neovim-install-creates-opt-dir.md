# 044 — neovim install creates /opt if missing

## Intent

`run_onchange_after_15-neovim.sh.tmpl` extracts the upstream Neovim tarball
with `tar -C /opt -xzf ...`. `tar -C <dir>` requires `<dir>` to already
exist — it does not create it. Some minimal systems (slim containers, some
distro base images) do not ship a `/opt` directory at all, so this step
fails with a tar error and the whole `chezmoi apply` — and therefore
`bootstrap.sh`, which runs it — aborts.

This spec makes the Neovim install step create `/opt` first when it is
missing, so bootstrap succeeds on systems without a pre-existing `/opt`.

## Acceptance criteria

- Before extracting, the script ensures `/opt` exists (e.g. `mkdir -p /opt`)
  using the same root/sudo escalation (`need_sudo`) already used for the
  rest of the install, so it also works as an unprivileged user with sudo.
- On systems where `/opt` already exists, behavior is unchanged (`mkdir -p`
  is a no-op).
- The extraction and symlink steps continue to work exactly as before.
- The implementation remains POSIX `sh` compatible.

## Out of scope

- Changing the install location away from `/opt`.
- Handling systems where `/opt` cannot be created at all (e.g. read-only
  root filesystem) — that remains a hard failure, same as today.

## Affected files

- `specs/044-neovim-install-creates-opt-dir.md` (new)
- `home/run_onchange_after_15-neovim.sh.tmpl` — create `/opt` before
  extracting into it.
- `tests/test_smoke.sh` — assert the script creates `/opt` before
  extracting.
