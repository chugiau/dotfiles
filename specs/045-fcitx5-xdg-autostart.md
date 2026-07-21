# 045 — Fcitx5 autostart via XDG autostart + systemd environment.d

## Intent

Fcitx5 currently only starts through `dot_zprofile`'s `command -v fcitx5`
guard (added in spec 004), which runs once per zsh **login shell** — e.g.
when a terminal tab opens. That is the wrong integration point for a
desktop input method on modern GNOME/Wayland:

- GDM starts the GNOME graphical session by execing `gnome-session`
  directly. It never sources `~/.zprofile` (a zsh login-shell file), so
  fcitx5 never autostarts at boot/login — it only ever started as a side
  effect of the user happening to open a terminal first.
- Even when it does start that way, the env vars `dot_zprofile` exports
  are only visible to processes forked from that one shell. They never
  reach the systemd `--user` session that GNOME Shell, D-Bus-activated
  services, and other GUI apps actually inherit their environment from.
- Since GNOME 49, gnome-session's own autostart-phase handling has been
  replaced by systemd: `~/.config/autostart/*.desktop` entries are turned
  into transient `app-<name>@autostart.service` units by
  `systemd-xdg-autostart-generator`, started under
  `xdg-desktop-autostart.target` as part of the systemd `--user`
  graphical session.
- `~/.config/environment.d/*.conf` files are read by
  `systemd-environment-d-generator` at systemd `--user` startup, and
  populate the session-wide environment inherited by every process in
  the session — not just children of one particular login shell.

This spec moves fcitx5's env vars and its startup out of `dot_zprofile`
and onto the systemd/XDG-native mechanisms GNOME 26.04 (GNOME Shell 50)
actually uses, so fcitx5 comes up automatically at login with no terminal
required.

This supersedes the `dot_zprofile`-related acceptance criteria in spec
004 (the `command -v fcitx5` guard around six env vars and `fcitx5 -d`).
Spec 004's zshenv/zprofile/zshrc split otherwise remains valid.

## Acceptance criteria

### `home/dot_config/environment.d/fcitx5.conf` (new)

- Plain (non-template) systemd environment.d file, `KEY=VALUE` per line,
  no shell syntax.
- Exports the same six input-method vars `dot_zprofile` used to set:
  `GTK_IM_MODULE=fcitx`, `QT_IM_MODULE=fcitx`, `QT_IM_MODULES=wayland;fcitx`,
  `XMODIFIERS=@im=fcitx`, `SDL_IM_MODULE=fcitx`, `GLFW_IM_MODULE=ibus`
  (GLFW has no native fcitx module; ibus is the documented compatibility
  shim).
- No `command -v fcitx5` guard: environment.d syntax can't express one.
  This is intentionally inert on machines without fcitx5 — GTK/Qt/SDL
  silently fall back to their default input method when the named IM
  module isn't installed, the same no-op behavior the old runtime guard
  produced.

### `home/dot_config/autostart/org.fcitx.Fcitx5.desktop` (new)

- Standard XDG autostart `.desktop` entry.
- `TryExec=fcitx5` so autostart processors (and the systemd generator)
  silently skip it on any machine without the binary — this is the
  autostart-file equivalent of the old `command -v fcitx5` guard.
- `Exec=fcitx5`, `Type=Application`, `NoDisplay=true` (autostart-only
  copy; the package's own `/usr/share/applications/org.fcitx.Fcitx5.desktop`
  already covers manual launch from the app grid).

### `home/dot_zprofile`

- The entire fcitx5 block is removed: no `command -v fcitx5` guard, no
  `INPUT_METHOD`/`GTK_IM_MODULE`/`QT_IM_MODULE`/`XMODIFIERS`/
  `SDL_IM_MODULE`/`GLFW_IM_MODULE` exports, no `pgrep`-guarded
  `fcitx5 -d` launch. None of that is `dot_zprofile`'s responsibility
  anymore.

### `.chezmoiignore`

- The two new paths (`.config/environment.d/fcitx5.conf`,
  `.config/autostart/org.fcitx.Fcitx5.desktop`) are added to the Windows
  branch's exclusion list, matching how `.zprofile` and other
  Unix-desktop-only paths are already excluded from native Windows
  applies.

### `tests/test_smoke.sh`

- The old `[dot_zprofile]` assertions that expected a `command -v fcitx5`
  guard, a `pgrep` check, and `SDL_IM_MODULE=fcitx` inside `dot_zprofile`
  are replaced with an assertion that `dot_zprofile` no longer mentions
  `fcitx5` (or any of the six env vars) at all.
- New assertions confirm `home/dot_config/environment.d/fcitx5.conf`
  exists and contains all six `KEY=VALUE` lines.
- New assertions confirm `home/dot_config/autostart/org.fcitx.Fcitx5.desktop`
  exists, has a `[Desktop Entry]` header, and contains `TryExec=fcitx5`.

## Out of scope

- The candidate-window-doesn't-render-over-gnome-shell-UI limitation
  (`mutter` implements `text-input-v3` but not the older `input-method`
  protocol fcitx5's popup positioning relies on). Fixing that means
  installing `gnome-shell-extension-kimpanel`, a separate cosmetic
  concern unrelated to autostart.
- Enabling the AppIndicator GNOME Shell extension for the tray icon.
- Any other `dot_zprofile` block (Homebrew `shellenv`, mise, etc.).
- Reconciling the *live* machine's current hand-edited `/etc/environment`
  and stale systemd session environment from prior manual
  troubleshooting — those are outside the repo and clear themselves up
  once environment.d + autostart take over on next login.

## Affected files

- `specs/045-fcitx5-xdg-autostart.md` (new)
- `home/dot_config/environment.d/fcitx5.conf` (new)
- `home/dot_config/autostart/org.fcitx.Fcitx5.desktop` (new)
- `home/dot_zprofile` (trim: remove fcitx5 block)
- `home/.chezmoiignore` (exclude new paths on Windows)
- `tests/test_smoke.sh` (updated assertions)
