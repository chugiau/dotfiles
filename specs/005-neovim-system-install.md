# 005 — Neovim: system-wide install from upstream pre-built tarball

## Intent

`home/dot_config/mise/config.toml` currently declares `neovim = "latest"`,
so `nvim` lives under `~/.local/share/mise/installs/neovim/...` and is
reached via the mise shim at `~/.local/share/mise/shims/nvim`. That shim
dir is only prepended to `$PATH` by `eval "$(mise activate zsh)"` inside
the interactive zsh rc — no other shell sees it.

Three concrete breakages follow from that:

1. **`sudoedit` / `sudo -e` / `sudo vim` / `sudo nvim`** resolve `nvim`
   through `sudo`'s `secure_path` (default
   `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`), which
   does not include the user's mise shim dir. Editing a root-owned file
   either falls back to `vi` or fails with "nvim: command not found".
2. **Root logins** (`sudo -i`, `su -`, real root) run their own shell
   without `mise activate`, so `$EDITOR=nvim` dangles.
3. **Cron / `crontab -e` / `visudo`** spawn `$EDITOR` under a minimal
   environment that likewise cannot see the mise shim.

All three want `nvim` on a path that is part of every user's default
`$PATH`, independent of mise activation. `/usr/local/bin` is on sudo's
default `secure_path` on every supported distro and on macOS, so a
symlink there makes `nvim` reachable from root, sudoedit, cron, and any
minimal shell for free.

The fix follows the upstream install guide at
<https://neovim.io/doc/install/>: download the pre-built tarball for the
host triple, extract to `/opt`, and drop a `/usr/local/bin/nvim`
symlink pointing at the extracted binary. Same flow for Linux and
macOS, four `(os, arch)` combinations total.

Version pinned to **v0.12.1** (current upstream stable, satisfies the
>= 0.11 requirement already asserted by `dotfiles doctor`). Bumping the
pin is a one-line edit to the script — the `run_onchange_` hash shift
triggers chezmoi to re-run the installer on the next `apply`.

## Acceptance criteria

### `home/dot_config/mise/config.toml`

- No longer declares `neovim` under `[tools]`. The remaining entries
  (`bat`, `eza`, `lazygit`, `glow`, `pnpm`, `bun`) stay.

### `home/run_onchange_after_15-neovim.sh.tmpl` (new file)

- POSIX sh, parses under `sh -n`, no bashisms.
- Pins the version at the top as `NVIM_VERSION="v0.12.1"` (bumping
  edits this one line; the `run_onchange_` content hash ensures chezmoi
  re-runs the script on the next `apply`).
- Detects host OS via `uname -s` (`Linux` → `linux`, `Darwin` →
  `macos`) and host arch via `uname -m`
  (`x86_64`/`amd64` → `x86_64`, `aarch64`/`arm64` → `arm64`). Anything
  else prints a clear error and exits non-zero.
- Downloads
  `https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-${os}-${arch}.tar.gz`
  with `curl -fL --proto =https --tlsv1.2` into a mktemp dir.
- Extracts to `/opt` using `sudo tar -C /opt -xzf`, wiping any
  pre-existing `/opt/nvim-${os}-${arch}` first so upgrades land on a
  clean tree.
- Creates or repoints `/usr/local/bin/nvim` to
  `/opt/nvim-${os}-${arch}/bin/nvim` via `ln -sfn` (under sudo). The
  symlink target must match exactly — no wrapper scripts, no copies.
- **Idempotent short-circuit:** if `/opt/nvim-${os}-${arch}/bin/nvim`
  already exists *and* reports a version string matching `NVIM_VERSION`,
  the script skips the download+extract entirely, but still repairs
  `/usr/local/bin/nvim` if the symlink is missing or points anywhere
  else.
- Reuses the same `need_sudo` helper pattern as
  `run_once_before_10-system-packages.sh.tmpl` (run as root directly if
  `id -u` is 0, else `sudo`, else die).
- Best-effort cleanup of the now-retired mise-managed install: if
  `command -v mise` succeeds *and* `mise ls neovim` reports a version,
  call `mise uninstall neovim --all` and `rm -f
  ~/.local/share/mise/shims/nvim` so the stale shim stops shadowing
  `/usr/local/bin/nvim` on the next `mise activate`. Failures here are
  logged but non-fatal.
- File ordering: `after_15` sits between
  `run_onchange_after_10-mise-install.sh.tmpl` and
  `run_once_after_20-ohmyzsh.sh.tmpl` / `run_once_after_30-nvchad.sh.tmpl`,
  so `nvim` is guaranteed to be on `/usr/local/bin` by the time
  the nvchad script runs `nvim --headless "+Lazy! sync" +qa`.

### `home/run_once_after_30-nvchad.sh.tmpl`

- The `PATH` export at the bottom no longer needs to prepend
  `~/.local/share/mise/shims` specifically for nvim. It may still
  prepend `~/.local/bin` (other tools), but the comment and the search
  order should reflect that `nvim` comes from `/usr/local/bin` now. Low
  priority — the existing prepend is harmless as long as the mise shim
  for nvim is actually gone, which the new installer ensures.

### `README.md`

- The "What Gets Installed" table row for **Dev tools** drops `neovim`
  from the mise-managed list.
- A new row (or updated **Editor config** row) records that Neovim is
  installed from the upstream tarball to `/opt/nvim-<os>-<arch>` with a
  `/usr/local/bin/nvim` symlink, and references
  `home/run_onchange_after_15-neovim.sh.tmpl`.
- The inline `[tools]` example under "Tool management via mise" no
  longer lists `neovim`.
- The "Updating" section still mentions the `nvim --headless "+Lazy!
  update" +qa` step (it runs against the system-installed nvim now, not
  a mise shim — behaviour is unchanged).

### `tests/test_smoke.sh`

- Asserts `home/run_onchange_after_15-neovim.sh.tmpl` exists, parses
  under `sh -n`, and contains no bashisms.
- Asserts the mise config no longer declares `neovim` under `[tools]`.
- Asserts the new script pins a version that starts with `v0.` and is
  at least `v0.11` (regex check on `NVIM_VERSION=`).
- Asserts the script downloads from
  `github.com/neovim/neovim/releases/download/` (no third-party
  mirrors, no unrelated URLs).
- Asserts the script installs into `/opt/nvim-` and symlinks into
  `/usr/local/bin/nvim`.
- Asserts the script handles all four `(os, arch)` combinations —
  `linux-x86_64`, `linux-arm64`, `macos-x86_64`, `macos-arm64` — by
  grepping for the mapping branches.
- Asserts the script has an idempotency short-circuit keyed on an
  installed version string matching `NVIM_VERSION`.
- Asserts the script best-effort cleans up the stale mise-managed
  neovim (`mise uninstall neovim` reference).
- Asserts the template renders via `chezmoi execute-template` and the
  rendered output parses under `sh -n` (picked up by the existing
  `run_*.sh.tmpl` loop, no new wiring needed).

## Out of scope

- Bumping past v0.12.1. Version bumps are a follow-up one-line edit to
  `NVIM_VERSION=` with a separate commit.
- Removing Homebrew's `neovim` formula on macOS boxes that already
  installed it that way. The symlink at `/usr/local/bin/nvim` may
  shadow a brew-installed binary on Intel Macs — that is the
  point; on Apple Silicon brew's prefix is `/opt/homebrew/bin` and
  there is no conflict to worry about.
- Fallback install paths for machines without a writable `/opt` or
  `/usr/local/bin`. Both are writable with sudo on every supported
  distro and on macOS.
- An auto-upgrade cadence separate from the dotfiles repo. Version
  bumps ride on normal commits, which is how every other pinned tool
  in this repo is managed.
- Restructuring `run_once_after_30-nvchad.sh.tmpl` to drop the
  mise-shim PATH prepend. It is harmless once the shim is cleaned up
  and touching it is out of scope.
- Shipping an uninstall script. `mise uninstall neovim --all` + `sudo
  rm -rf /opt/nvim-* /usr/local/bin/nvim` is a two-line operation that
  does not need its own wrapper.

## Affected files

- `specs/005-neovim-system-install.md` (new)
- `home/dot_config/mise/config.toml` (drop `neovim`)
- `home/run_onchange_after_15-neovim.sh.tmpl` (new)
- `README.md` (tool table + inline `[tools]` example)
- `tests/test_smoke.sh` (new assertions)
