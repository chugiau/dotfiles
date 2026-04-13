# 008 — Install gh + glab via mise

## Intent

Day-to-day work against GitHub and GitLab repositories routinely reaches
for the two vendor CLIs:

- **`gh`** — [GitHub CLI](https://cli.github.com/). Claude Code itself
  already shells out to `gh` for PR creation, issue inspection, and CI
  status checks (see the `# Creating pull requests` / `gh pr create`
  block in the Claude Code system prompt). Without `gh` on `PATH`, those
  flows fall back to manual `git push` + opening a browser.
- **`glab`** — [GitLab CLI](https://gitlab.com/gitlab-org/cli). Same
  shape as `gh`, for the GitLab-hosted repos that the rest of the
  toolchain also needs to reach.

Both are distributed as single static binaries with no runtime
dependencies, and both are first-class entries in mise's registry:

```
$ mise registry | grep -E '^(gh|glab)'
gh     aqua:cli/cli                 asdf:bartlomiejdanek/asdf-github-cli
glab   gitlab:gitlab-org/cli        asdf:mise-plugins/mise-glab
```

Adding `gh` and `glab` to `home/dot_config/mise/config.toml` therefore
drops them straight into `~/.local/share/mise/shims/` on the next
`dotfiles install`, alongside `bat`, `eza`, `lazygit`, `glow`, `node`,
`pnpm`, and `bun`. No distro package, no curl-pipe script, no signing
key management — the same update cadence as the rest of the manifest.

This spec follows the spec-002 (pnpm) / spec-003 (bun) precedent rather
than spec 006 (node): `gh` and `glab` are leaf tools whose absence is
obvious the moment you type the command, so they do **not** join the
`bin/dotfiles doctor` loop. A missing `gh` surfaces as "command not
found", not as a cryptic LSP or hook failure, so there is no debugging
win from pre-flighting it in the doctor.

## Acceptance criteria

### `home/dot_config/mise/config.toml`

- Declares `gh = "latest"` under `[tools]`, pinned to `latest` to match
  the surrounding entries.
- Declares `glab = "latest"` under `[tools]`, likewise pinned to
  `latest`.
- The two new lines sit together at the tail of the `[tools]` block (a
  "forges" grouping), after the JS-toolchain lines (`node`, `pnpm`,
  `bun`), so the manifest visually groups file viewers → JS toolchain
  → forge CLIs.

### `tests/test_smoke.sh`

- Asserts that `mise/config.toml` declares `gh` under `[tools]`,
  mirroring the existing `pnpm` / `bun` / `node` assertions so a
  regression (someone deleting the line) is caught by the smoke suite.
- Asserts the same for `glab`.

### `README.md`

- The "What Gets Installed" table row for **Dev tools** lists `gh` and
  `glab` alongside the existing mise-managed entries.
- The inline `[tools]` example block under "Tool management via mise"
  shows the `gh = "latest"` and `glab = "latest"` lines, in the same
  position as the manifest.

## Out of scope

- Adding `gh` or `glab` to the `bin/dotfiles doctor` loop — see the
  intent section for why (leaf-tool rationale, matches spec 002/003).
- Authenticating `gh` / `glab` against github.com or gitlab.com. That is
  a per-machine interactive step (`gh auth login`, `glab auth login`)
  with no secret material to commit, and does not belong in a dotfiles
  spec.
- Shell completion wireups. Both CLIs emit completion via
  `gh completion -s zsh` / `glab completion -s zsh`, but oh-my-zsh
  already picks up completion from the mise shim PATH; nothing explicit
  to add here.
- Installing any related tools (`hub`, `tea`, Codeberg's `berg`, …).
  Only the two CLIs named above.
- Touching `CLAUDE.md` / `AGENTS.md` — the Claude Code system prompt
  already documents `gh` usage; there is no new repo convention to
  record.

## Affected files

- `specs/008-gh-glab-via-mise.md` (new)
- `home/dot_config/mise/config.toml` (add `gh` and `glab` lines)
- `tests/test_smoke.sh` (two new assertions: gh + glab in mise config)
- `README.md` (Dev tools row + inline `[tools]` example)
