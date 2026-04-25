# 020 — Shell autocomplete wiring

## Intent

Today's autocomplete coverage in this dotfiles repo is patchwork:

- The OPENSPEC block at the top of `home/dot_zshrc` calls `compinit`
  once; oh-my-zsh then calls it again on line 62. Both run, neither
  is wrong, neither is coordinated.
- Three bespoke completion blocks live further down: `tofu` uses
  `complete -C` (line 73-75), `dotnet` declares a custom
  `_dotnet_zsh_complete` (line 99-112), `bun` sources
  `~/.bun/_bun` (line 119-123). Each is one-off; nothing shares a
  pattern.
- mise installs eleven CLIs (`bat`, `eza`, `lazygit`, `glow`,
  `ripgrep`, `node`, `bun`, `gh`, `glab`, `codex`, `direnv`) but
  none of them get their completions wired up. Empirical probe of
  `~/.local/share/mise/installs/` shows `bat` ships
  `autocomplete/bat.zsh`, `ripgrep` ships `complete/_rg`, `glow`
  ships `completions/glow.zsh`; `lazygit`, `glow`, `gh`, `glab`,
  `codex` all support a `<tool> completion zsh` subcommand. Without
  this spec, none of those land in `fpath`.
- `home/run_once_before_10-system-packages.sh.tmpl` installs zsh
  itself plus core utilities, but no `bash-completion` package — so
  any system tool that only ships a bash completion script (the
  common case for HashiCorp / AWS / many distro utilities) goes
  silently uncompleted in zsh.
- No `zsh-syntax-highlighting` / `zsh-autosuggestions` despite both
  being a near-universal default for modern zsh setups.

This spec wires up the three layers in one coherent change:

1. **System scope** — system PM installs `bash-completion`,
   `zsh-syntax-highlighting`, `zsh-autosuggestions`, plus
   `zsh-completions` (the upstream extra-completions collection)
   where the distro packages it. zsh's default `fpath` already picks
   up `/usr/share/zsh/site-functions/` and
   `/usr/share/zsh/vendor-completions/`, where each tool package
   drops its `_<tool>` file.
2. **User scope (mise-managed tools)** — a new `run_onchange`
   chezmoi script generates `_<tool>` files into
   `$HOME/.local/share/zsh/completions/`, regenerated whenever
   the mise manifest hash changes. A new `completions.zsh` shell
   module prepends that directory to `fpath` *before* anything
   else, so user-scope wins over system-scope on overlap.
3. **Project / local scope** — not implemented as a separate
   `fpath` layer. `mise activate` already swaps the underlying
   binary per-project at runtime via shims (spec 007); the
   generated static completion script invokes the shim, the shim
   resolves the project-pinned version, completion works. Per-tool
   flag-set differences across versions exist but are bounded; the
   trade-off is called out in *Out of scope* below.

`bash-completion` compatibility is enabled by appending an
`autoload -U +X bashcompinit && bashcompinit` line at the bottom of
`dot_zshrc` — *after* oh-my-zsh's `compinit` runs, which
`bashcompinit` requires.

`zsh-syntax-highlighting` and `zsh-autosuggestions` are sourced
from their distro-package locations at the very end of
`dot_zshrc`. Per upstream, `zsh-syntax-highlighting` must load
last; the source order in the file reflects that.

The OPENSPEC `compinit` block (`dot_zshrc:13-18`) is **not
touched**. OpenSpec's installer can rewrite that region; the new
module operates independently and does not need OpenSpec's
cooperation. The duplicate `compinit` call (OPENSPEC + omz) costs
a few ms at shell startup and is left alone.

## Acceptance criteria

### `home/dot_config/dotfiles/modules/completions.zsh` (new)

- File exists and is sourced from `home/dot_zshrc` *before* the
  `source $ZSH/oh-my-zsh.sh` line (so its `fpath` addition is in
  scope when oh-my-zsh runs `compinit`).
- The module guards on `[ -d "$HOME/.local/share/zsh/completions" ]`
  before touching `fpath`, so a fresh-bootstrap machine that has
  not yet run the run_onchange generator still sources cleanly.
- The module prepends — not appends — to `fpath`. The user-scope
  directory must come *before* `/usr/share/zsh/site-functions` /
  `/usr/share/zsh/vendor-completions` so a mise-generated `_gh`
  beats a distro-shipped `_gh`.
- The module declares `typeset -U fpath` so duplicate entries
  (e.g. if the OPENSPEC block re-sets `fpath` later) collapse
  rather than accumulate across re-sources.

### `home/run_onchange_after_16-completions.sh.tmpl` (new)

- POSIX sh, mirrors the structure of
  `run_onchange_after_10-mise-install.sh.tmpl`.
- Top-of-file comment includes a chezmoi hash directive
  `# completion-config-hash: {{ include "dot_config/mise/config.toml" | sha256sum }}`
  so any edit to the mise manifest re-runs this generator.
- Creates `$HOME/.local/share/zsh/completions` with `mkdir -p`.
- Generates a completion file per tool from the table below. Each
  step short-circuits with `command -v <tool> >/dev/null 2>&1 ||
  continue` so a fresh-bootstrap run that hasn't yet finished
  `mise install` does not abort:

  | Tool      | Source                                                                       | Output      |
  |-----------|------------------------------------------------------------------------------|-------------|
  | `bat`     | shipped: glob `~/.local/share/mise/installs/bat/*/*/autocomplete/bat.zsh`    | `_bat`      |
  | `ripgrep` | shipped: glob `~/.local/share/mise/installs/ripgrep/*/*/complete/_rg`        | `_rg`       |
  | `lazygit` | `lazygit completion zsh`                                                     | `_lazygit`  |
  | `glow`    | `glow completion zsh`                                                        | `_glow`     |
  | `gh`      | `gh completion -s zsh`                                                       | `_gh`       |
  | `glab`    | `glab completion -s zsh`                                                     | `_glab`     |
  | `codex`   | `codex completion zsh`                                                       | `_codex`    |

- Tools deliberately skipped, with a one-line `# skip: …` comment
  in the script body explaining why:
  - `eza` — release tarball strips completions; would need a
    separate upstream raw-fetch.
  - `node` — no native completion (npm has its own; deferred).
  - `bun` — mise-bun completion would need `bun completions` which
    writes to a fixed location; standalone-bun fallback in
    `dot_zshrc:119-123` already covers that case.
  - `direnv` — no completion subcommand upstream.

- Generation is idempotent: each invocation overwrites the target
  file; no incremental merge.

### `home/run_once_before_10-system-packages.sh.tmpl`

- Debian/Ubuntu branch (`install_debian`) adds
  `bash-completion zsh-syntax-highlighting zsh-autosuggestions`
  to its apt install list.
- Arch branch (`install_arch`) adds
  `bash-completion zsh-completions zsh-syntax-highlighting zsh-autosuggestions`
  to its pacman install list.
- Fedora branch (`install_fedora`) adds
  `bash-completion zsh-syntax-highlighting zsh-autosuggestions`
  to its dnf install list.
- Darwin branch (`install_darwin`) adds
  `bash-completion@2 zsh-completions zsh-syntax-highlighting zsh-autosuggestions`
  to its brew install list.
- All four branches keep their existing package lists intact —
  this is purely additive.

### `home/dot_zshrc`

- A new `source "$DOTFILES/modules/completions.zsh"` line sits
  *above* the existing `source $ZSH/oh-my-zsh.sh` (currently
  line 62). The module's `fpath` change must take effect before
  oh-my-zsh runs `compinit`.
- A new `autoload -U +X bashcompinit && bashcompinit` line sits
  *below* `source $ZSH/oh-my-zsh.sh` and *below* the
  `[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh` line. Comment
  clarifies the placement: `bashcompinit` requires `compinit`
  to have already run.
- At the very bottom of the file (after `mise activate`,
  `direnv hook`, the VSCode integration line, and the peon-ping
  alias), two `for f in … done` loops source
  `zsh-autosuggestions.zsh` and `zsh-syntax-highlighting.zsh`
  from their distro-package locations
  (`/usr/share/zsh-autosuggestions/`,
  `/opt/homebrew/share/zsh-autosuggestions/`,
  and the matching pair for syntax-highlighting). Each loop
  sources the first file found and breaks. Order matters:
  autosuggestions first, syntax-highlighting last (per upstream
  docs).
- The OPENSPEC block (lines 13-18) is *unchanged*. The three
  existing per-tool blocks (`tofu`, `dotnet`, standalone-`bun`)
  are *unchanged*.

### `tests/test_smoke.sh`

A new `[completions]` section asserts:

- `check_exists "home/dot_config/dotfiles/modules/completions.zsh"`
- `check_exists "home/run_onchange_after_16-completions.sh.tmpl"`
- `check_sh_parse "home/run_onchange_after_16-completions.sh.tmpl"`
- `check_no_bashisms "home/run_onchange_after_16-completions.sh.tmpl"`
- The new run_onchange template contains a
  `completion-config-hash:` line (mirrors the spec-010
  `mise-config-hash` smoke check pattern).
- `home/dot_zshrc` contains a `source "$DOTFILES/modules/completions.zsh"`
  line.
- `home/dot_zshrc` contains a `bashcompinit` invocation.
- `home/dot_zshrc` contains references to both
  `zsh-autosuggestions.zsh` and `zsh-syntax-highlighting.zsh`.
- `home/run_once_before_10-system-packages.sh.tmpl` contains
  `bash-completion` in the Debian, Arch, Fedora, and Darwin
  branches.
- `home/run_once_before_10-system-packages.sh.tmpl` contains
  `zsh-syntax-highlighting` and `zsh-autosuggestions` for those
  same four branches.

`sh tests/test_smoke.sh` passes from the repo root.

### `README.md`

- The "What Gets Installed" section gains a one-line note for
  shell autocomplete pointing at this spec. No table-shape
  rewrite — additive only.

## Out of scope

- **Per-project completion overrides.** mise has no native concept
  of a per-cwd `_<tool>` file, and zsh's `compinit` is a one-shot
  invocation per shell. Implementing project-scope completions
  would require either a second `compinit` per `cd` (slow) or a
  custom completion-dispatcher per tool. Neither is justified for
  the current toolchain — every tool listed in
  `dot_config/mise/config.toml` ships completions whose flag-set
  drift across versions is bounded enough that a single
  user-scope file works in practice. If a future tool breaks this
  assumption, this spec is the place to amend.
- **Removing the OPENSPEC `compinit` block** (`dot_zshrc:13-18`).
  OpenSpec's installer owns that region; touching it invites
  re-installation drift. The duplicate `compinit` call (OPENSPEC
  + oh-my-zsh) costs a few milliseconds at shell startup.
- **Replacing the per-tool `tofu`/`dotnet`/standalone-`bun`
  blocks** with the new generator. Those tools are not mise-
  managed (or, for standalone-bun, are an explicit fallback for
  the non-mise install). Their completion paths are already
  working; rewriting for uniformity would be churn.
- **`eza` completion file generation.** Upstream's release
  tarball strips the `completions/` directory. Wiring it would
  require either a raw-`curl` fetch from
  `github.com/eza-community/eza/raw/main/completions/zsh/_eza`
  or a build-from-source path. Both are larger than this spec
  warrants; defer until a user actually files a complaint.
- **`npm completion` for the mise-managed Node.** Belongs in a
  follow-up spec that decides whether the Node-side completion
  story (npm, npx, bunx, …) wants its own treatment.
- **mise-managed `bun` completion.** `bun completions` writes to a
  fixed `~/.bun/_bun` path that the existing
  `dot_zshrc:119-123` block already sources. Re-routing through
  the new generator would mean re-implementing what bun's own
  completion-installer does; not worth it for the current tool.
- **Touching `dot_zprofile` or `dot_zshenv.tmpl`.** Those files
  control PATH and env at login; completion wiring is an
  interactive-shell concern and lives in `dot_zshrc`.
- **Modifying `bin/dotfiles doctor`.** No new health check for
  completion is added — a missing `_<tool>` file surfaces as
  "no completion offered", which is self-evident at the prompt.

## Affected files

- `specs/020-shell-completions.md` (new)
- `home/dot_config/dotfiles/modules/completions.zsh` (new)
- `home/run_onchange_after_16-completions.sh.tmpl` (new)
- `home/run_once_before_10-system-packages.sh.tmpl` (add packages
  to all four distro branches; no other changes)
- `home/dot_zshrc` (three edits: source new module before omz;
  `bashcompinit` after p10k; source system zsh-{auto,syntax} at
  end of file)
- `tests/test_smoke.sh` (one new `[completions]` section per the
  acceptance criteria above)
- `README.md` (one-line note under "What Gets Installed")
