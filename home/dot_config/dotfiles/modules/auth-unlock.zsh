# Terminal auth unlock wiring for SSH/GPG prompts.
#
# Keep this before p10k instant prompt: it does not prompt by itself, but it
# prepares agent-mediated prompts that may happen later in the shell session.

_auth_unlock_has_gui() {
  [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" || "$(uname -s 2>/dev/null)" == "Darwin" ]]
}

_auth_unlock_pick_ssh_askpass() {
  if [[ -n "${SSH_ASKPASS:-}" ]]; then
    [[ -x "$SSH_ASKPASS" ]]
    return
  fi

  local askpass
  for askpass in \
    /usr/bin/ssh-askpass \
    /usr/lib/ssh/ssh-askpass \
    /usr/libexec/ssh-askpass \
    /usr/libexec/openssh/ssh-askpass \
    /usr/bin/ksshaskpass \
    /usr/bin/lxqt-openssh-askpass \
    /opt/homebrew/bin/ssh-askpass \
    /usr/local/bin/ssh-askpass; do
    if [[ -x "$askpass" ]]; then
      export SSH_ASKPASS="$askpass"
      return 0
    fi
  done

  return 1
}

if _auth_unlock_has_gui && _auth_unlock_pick_ssh_askpass; then
  export SSH_ASKPASS_REQUIRE="prefer"
fi

if command -v tty >/dev/null 2>&1; then
  _auth_unlock_tty="$(tty 2>/dev/null || true)"
  if [[ -n "$_auth_unlock_tty" && "$_auth_unlock_tty" != "not a tty" ]]; then
    export GPG_TTY="$_auth_unlock_tty"
    if command -v gpg-connect-agent >/dev/null 2>&1; then
      gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
    fi
  fi
  unset _auth_unlock_tty
fi
