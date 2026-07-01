# 038 - p10k and direnv startup handshake

## Intent

Avoid Powerlevel10k instant-prompt warnings when an interactive zsh starts
inside a directory that direnv is allowed to load.

The permanent direnv hook still belongs after `mise activate zsh`, because the
managed `direnv` binary comes from mise. The missing piece is the one-time
direnv environment export before the p10k instant-prompt block, following
Powerlevel10k's documented direnv integration pattern. That gives the instant
prompt the same initial environment that the first real prompt will see, so the
later direnv hook does not produce first-prompt startup output.

## Acceptance criteria

- `home/dot_zshrc` runs a guarded `direnv export zsh` before the
  `p10k-instant-prompt` source block.
- The one-time export uses `emulate zsh -c "$(direnv export zsh)"`, matching
  Powerlevel10k's zsh-safe integration shape.
- The existing guarded `direnv hook zsh` block remains after
  `mise activate zsh`.
- Smoke tests fail if the one-time export is missing, placed after p10k, or
  replaced with the permanent hook before p10k.

## Out of scope

- Disabling Powerlevel10k instant prompt.
- Moving the permanent direnv hook before `mise activate zsh`.
- Silencing direnv globally with `DIRENV_LOG_FORMAT`.
- Adding a second direnv installation path outside mise.

## Affected files

- `specs/038-p10k-direnv-startup.md`
- `home/dot_zshrc`
- `tests/test_smoke.sh`
- `README.md`
