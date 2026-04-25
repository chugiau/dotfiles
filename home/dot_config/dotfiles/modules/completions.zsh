# Spec 020 — shell autocomplete wiring (user-scope completions).
#
# This module prepends the user-scope completion directory to fpath
# so completions generated for mise-managed tools by
# run_onchange_after_16-completions.sh.tmpl shadow any same-named
# system-scope completions (/usr/share/zsh/{site-functions,vendor-
# completions}). The controlling rule is "earlier in fpath wins";
# see the spec for the system / user / project scope-resolution
# rationale.
#
# Sourced from dot_zshrc *before* `source $ZSH/oh-my-zsh.sh` so
# omz's compinit picks up the new fpath entry on its single
# invocation. The module guards on the user-scope dir existing so
# a fresh-bootstrap shell (one where the run_onchange has not yet
# materialised the directory) still sources cleanly.

# Collapse duplicate fpath entries — the OPENSPEC block at the top
# of dot_zshrc may also reset fpath later; typeset -U keeps the
# final array clean.
typeset -U fpath

if [ -d "$HOME/.local/share/zsh/completions" ]; then
  fpath=("$HOME/.local/share/zsh/completions" $fpath)
fi
