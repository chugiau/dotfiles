# 026 - Terminal auth unlock prompts

## Intent

Terminal-driven automation often reaches a point where the user must unlock a
secret: an encrypted SSH key, an OpenPGP key used by `git commit -S`, or a
similar agent-mediated credential. In WSL2 this is especially disruptive for AI
agent workflows because the agent may be running non-interactively while the
human is still available to approve a GUI prompt.

Make the dotfiles provide a predictable unlock path for interactive shells:
GPG uses a pinentry wrapper that prefers a graphical prompt when a GUI session is
available and falls back to terminal pinentry otherwise; SSH uses `ssh-agent`
plus `ssh-askpass` when graphical prompting is available; both cache successful
unlocks for a bounded, reasonable period.

## Acceptance criteria

- The shell exports `GPG_TTY` from the current TTY and refreshes the running
  `gpg-agent` startup TTY so terminal fallback pinentry works after changing
  terminals or panes.
- GPG agent configuration uses a managed `pinentry-auto` wrapper and sets a
  bounded cache: one hour default TTL and four hour maximum TTL.
- The `pinentry-auto` wrapper chooses GUI pinentry programs first when `DISPLAY`
  or `WAYLAND_DISPLAY` is present, including the WSLg case, and falls back to
  curses/TTY pinentry programs when no GUI is available.
- The shell exports `SSH_ASKPASS` and `SSH_ASKPASS_REQUIRE=prefer` when a GUI
  session and an installed askpass helper are present, without overwriting an
  existing explicit `SSH_ASKPASS`.
- `ssh-agent` starts with a four hour default identity lifetime so unlocked SSH
  keys are cached but do not live indefinitely.
- SSH client configuration enables `AddKeysToAgent yes` so passphrase-protected
  keys unlocked by `ssh` are inserted into the running agent cache.
- System package bootstrap installs GUI and terminal pinentry/askpass helpers on
  supported package-manager branches where package names are available.
- `dotfiles test` parses the new zsh module and executable helper.
- README documents the behavior and the cache duration.

## Out of scope

- Replacing OpenSSH `ssh-agent` with `gpg-agent` SSH support.
- Importing, generating, or backing up SSH or GPG private keys.
- Enabling Git commit signing globally; the existing `commit.gpgSign = false`
  default remains unchanged.
- Guaranteeing GUI prompts on machines with no GUI forwarding/session.
- Managing custom per-host SSH identities beyond the global `AddKeysToAgent`
  default.

## Affected files

- `specs/026-terminal-auth-unlock.md` (new)
- `home/dot_config/dotfiles/modules/auth-unlock.zsh` (new)
- `home/dot_config/dotfiles/modules/ssh-agent.zsh`
- `home/dot_config/dotfiles/bin/executable_pinentry-auto` (new)
- `home/private_dot_gnupg/gpg-agent.conf.tmpl` (new)
- `home/private_dot_ssh/config` (new)
- `home/dot_zshrc`
- `home/run_once_before_10-system-packages.sh.tmpl`
- `bin/dotfiles`
- `tests/test_smoke.sh`
- `README.md`
