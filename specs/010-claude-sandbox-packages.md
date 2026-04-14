# 010 — System packages for Claude Code sandbox mode

## Intent

Claude Code ships a sandboxed bash tool that uses OS primitives to
enforce filesystem + network isolation per bash call. On macOS it
uses the built-in Seatbelt framework (nothing to install). On Linux
and WSL2 it uses [`bubblewrap`](https://github.com/containers/bubblewrap)
for filesystem/namespace isolation and `socat` as the plumbing for
the network proxy that enforces the domain allowlist. Upstream docs
say so explicitly — on Ubuntu/Debian `sudo apt-get install bubblewrap
socat`, on Fedora `sudo dnf install bubblewrap socat`.

Today none of the Linux branches of
`home/run_once_before_10-system-packages.sh.tmpl` install either
package. Running `/sandbox` on a fresh dotfiles bootstrap therefore
always falls back to the "missing deps" menu and either runs
unsandboxed (the soft default) or hard-fails (when
`sandbox.failIfUnavailable` is set). Fix it by listing `bubblewrap`
and `socat` in `install_debian`, `install_arch`, and
`install_fedora`, so every Linux bootstrap — native or WSL2 — comes
up sandbox-capable without any extra manual step.

macOS is out of scope: Seatbelt is built into the OS and Claude
Code's sandbox works out of the box on a fresh `install_darwin`.
Adding a no-op package there is noise.

## Acceptance criteria

### `home/run_once_before_10-system-packages.sh.tmpl`

- `install_debian()` installs `bubblewrap` **and** `socat` as part
  of the main `apt-get install` call (not a separate guarded step —
  these are hard dependencies of sandbox support on every Debian
  box, not a WSL-only extra like `wslu`).
- `install_arch()` installs `bubblewrap` and `socat` via
  `pacman -Sy --needed` on the same line as the rest of the base
  packages.
- `install_fedora()` installs `bubblewrap` and `socat` via
  `dnf install -y` on the same line as the rest of the base
  packages.
- `install_darwin()` is **unchanged** — Seatbelt is built into
  macOS, no extra package is needed.
- The script is still idempotent (apt/pacman/dnf skip packages that
  are already present) and still POSIX-sh clean.
- Package-name ordering in each distro's install line is
  alphabetical-ish but not strictly enforced; the test only checks
  that both names appear on the install line for that distro's
  function.

### `tests/test_smoke.sh`

- A new `[spec 010 — claude sandbox packages]` block, added before
  the `# ── Summary` tail, asserts that
  `home/run_once_before_10-system-packages.sh.tmpl`:
  1. `install_debian` installs `bubblewrap`.
  2. `install_debian` installs `socat`.
  3. `install_arch` installs `bubblewrap`.
  4. `install_arch` installs `socat`.
  5. `install_fedora` installs `bubblewrap`.
  6. `install_fedora` installs `socat`.
  7. `install_darwin` does **not** mention `bubblewrap` or `socat`
     (macOS uses Seatbelt; a brew line for either would be dead
     weight and would signal the spec has drifted).
- The per-function check reuses the `awk` scope-matching pattern
  already used by the `[chezmoi age wiring]` block (lines 670–685)
  so it only matches package names inside the function body, not
  elsewhere in the file.

## Out of scope

- Installing sandbox packages on macOS. Seatbelt is built in; a
  brew line would be dead weight.
- Writing a `~/.claude/settings.json` fragment that enables
  `sandbox.enabled` or `sandbox.autoAllow`. Sandbox mode is opt-in
  per user preference (`/sandbox` menu); this spec only makes the
  opt-in possible, it does not flip the switch.
- Tuning `sandbox.filesystem.allowWrite`, `allowedDomains`, or any
  other sandbox config. Those are per-project and per-user.
- Adding a `bwrap` / `socat` probe to `bin/dotfiles doctor`. Doctor
  covers the mise-managed tool set; sandbox deps are a separate
  category and not worth a new loop for two binaries.
- Alpine, Void, NixOS, or any other distro not already listed in
  the template's dispatch block. Adding a distro is its own spec
  per `AGENTS.md`'s "Adding a distro" section.
- WSL1. Upstream says WSL1 is not supported by the sandbox at all
  (bubblewrap needs kernel features only present in WSL2), so
  there is nothing to install for it.

## Affected files

- `specs/010-claude-sandbox-packages.md` (new)
- `home/run_once_before_10-system-packages.sh.tmpl` (add
  `bubblewrap socat` to `install_debian`, `install_arch`,
  `install_fedora`)
- `tests/test_smoke.sh` (new `[spec 010 — claude sandbox packages]`
  block)
