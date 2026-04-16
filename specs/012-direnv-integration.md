# 012 — direnv integration

## Intent

Ship [direnv](https://direnv.net/) on every machine and wire it into
zsh so that `cd`ing into a directory with an `.envrc` **or** a bare
`.env` exports the file's variables into the current shell (after a
one-time `direnv allow`), and `cd`ing out unexports them.

Before this spec, per-project environment variables had to be sourced
manually or wired through ad-hoc zshrc functions. direnv solves this
cleanly: a single `precmd` hook diffs the target directory's declared
env against the current shell and applies the delta, preserving the
rest of the environment untouched.

Two design choices drive the shape:

1. **Install the binary via mise.** `direnv` is first-class in mise's
   registry:

   ```
   $ mise registry | grep '^direnv'
   direnv   aqua:direnv/direnv
   ```

   The aqua backend pulls a single static binary from the upstream
   GitHub release, so `direnv = "latest"` in
   `home/dot_config/mise/config.toml` drops it straight into
   `~/.local/share/mise/shims/` on the next `dotfiles install`. Same
   cadence as `gh`, `glab`, `bun`, `codex` — spec 008 / 003 / 011
   precedent.

2. **`[global] load_dotenv = true`.** By default direnv activates on
   `.envrc` only. Setting `load_dotenv = true` in
   `~/.config/direnv/direnv.toml` (direnv ≥ 2.31) extends this so bare
   `.env` files activate too, which is the idiomatic
   "drop-a-`.env`-in-a-project" flow most toolchains already assume.
   The `direnv allow` approval step still applies per directory — it
   is direnv's security model, deliberately not circumvented.

This spec follows the leaf-tool pattern (specs 002, 003, 008, 011):
`direnv`'s absence surfaces as "command not found" the moment you
type the command, so it does **not** join the `bin/dotfiles doctor`
loop.

## Acceptance criteria

### `home/dot_config/mise/config.toml`

- Declares `direnv = "latest"` under `[tools]`, appended at the tail
  of the manifest after `codex`. The manifest's visual grouping
  extends to: file viewers → JS toolchain → forge CLIs → coding
  agents → shell integrations.

### `home/dot_config/direnv/direnv.toml` (new)

- Declares a `[global]` section with `load_dotenv = true` so bare
  `.env` files activate without requiring an accompanying `.envrc`.
- Carries a short header comment naming the setting and reminding a
  future reader that `direnv allow` is still required per directory.

### `home/dot_zshrc`

- Adds an `eval "$(direnv hook zsh)"` block **after** the existing
  `mise activate zsh` block. Placement matters: direnv's hook runs on
  every `precmd`, and it needs the mise-shimmed `direnv` binary on
  PATH at eval time. Putting it after mise activate guarantees that.
- The eval is guarded on `command -v direnv >/dev/null 2>&1` so a
  machine that has not yet run `dotfiles install` still loads a
  working interactive shell without a shell error.
- A short comment block documents the ordering rationale and the
  `load_dotenv = true` global so a future reader does not "fix" the
  ordering or duplicate the config.

### `tests/test_smoke.sh`

- Asserts `mise/config.toml` declares `direnv` under `[tools]` (same
  `awk section == "[tools]"` shape as the existing `gh` / `glab` /
  `bun` / `codex` / `node` checks).
- Registers `home/dot_config/direnv/direnv.toml` in the
  `[home/ source tree]` existence loop.
- Asserts `home/dot_config/direnv/direnv.toml` declares
  `[global] load_dotenv = true`.
- Asserts `dot_zshrc` calls `eval "$(direnv hook zsh)"` guarded on
  `command -v direnv`.
- Asserts the `direnv hook zsh` line's `NR` is greater than the
  `mise activate zsh` line's — reusing the `awk NR`-comparison
  pattern already used for the spec-007 "mise activate must run
  after PATH prepends" check.

### `README.md`

- Dev-tools row lists `direnv` alongside the existing mise-managed
  entries.
- Inline `[tools]` example block shows the `direnv = "latest"` line.
- A Post-Install Manual Steps entry notes that per-directory
  `direnv allow` is required on first entry — direnv's security
  model, not a bug.

## Out of scope

- **`bin/dotfiles doctor` loop.** Leaf-tool rationale — matches spec
  002 / 003 / 008 / 011. A missing `direnv` surfaces as "command not
  found", not a cryptic downstream failure.
- **Changing `.gitignore` or the pre-commit `.env` block.** Those
  guard *this dotfiles repo's* commits — real secrets stay out of
  VCS. direnv reads `.env` from user project directories at
  *runtime*. Different scopes; touching either would regress secret
  hygiene.
- **Shipping a repo-local `.envrc` for the dotfiles repo itself.** The
  repo has no per-user env vars to load; adding one would be noise.
- **Authoring `.envrc` boilerplate or project templates.** Per-project
  concern, not a dotfiles concern.
- **Wiring mise's own `use mise` directive into `.envrc` files.**
  That is a per-project opt-in (`mise` ↔ `direnv` interop). Nothing
  to configure at the dotfiles layer.
- **Touching `CLAUDE.md` / `AGENTS.md`.** Additive leaf-tool change
  with no new repo convention to record.

## Affected files

- `specs/012-direnv-integration.md` (new)
- `home/dot_config/mise/config.toml` (append `direnv` line)
- `home/dot_config/direnv/direnv.toml` (new, a handful of lines with
  comment)
- `home/dot_zshrc` (guarded `direnv hook zsh` eval after mise
  activate)
- `tests/test_smoke.sh` (new assertions: mise entry, direnv.toml
  existence and `load_dotenv = true`, zshrc hook + guard + ordering)
- `README.md` (Dev-tools row + inline `[tools]` example +
  Post-Install entry for `direnv allow`)
