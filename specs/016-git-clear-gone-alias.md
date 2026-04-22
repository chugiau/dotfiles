# 016 — `git clear-gone` alias

## Intent

After landing PRs (squash, rebase-and-merge, or merge-commit), the
local feature branch sits on the developer's machine pointing at
commits that no longer exist on the upstream. `git fetch --prune`
flips the upstream tracking state to `gone`, but the local branch
itself stays behind, accumulating dead refs that clutter `git branch`,
fzf branch pickers, statusline branch counts, etc.

The hand-typed cleanup is annoying enough that everyone reinvents it,
typically as `git branch -vv | awk '/: gone]/ {print $1}' | xargs git branch -D`.
This spec promotes that one-liner to a single-token alias under
`home/dot_gitconfig` so `git clear-gone` works out of the box on every
machine the dotfiles touch.

## Design

- **Use `git for-each-ref`**, not `git branch -vv`. `for-each-ref` is
  the porcelain-stable scripting interface; `branch -vv`'s output is
  shaped for humans and varies with locale and decoration settings.
  The format `'%(refname:short) %(upstream:track)'` yields one branch
  per line, with `[gone]` in column 2 exactly when the upstream is
  gone — easy to filter with `awk '$2 == "[gone]"'`.

- **Refresh first with `git fetch --all --prune`.** A branch only
  acquires the `[gone]` marker after the prune flips its upstream
  state, so an alias that skips this step would silently no-op on
  any clone where the user just ran `git pull` (which does not prune
  by default). `--all` covers multi-remote setups, where the upstream
  may live on `upstream` rather than `origin`.

- **Force delete via `git branch -D`.** A `gone` branch is typically
  the local side of a squash- or rebase-merged PR; `git branch -d`
  refuses it as "not fully merged" because the upstream merge produced
  fresh SHAs. The whole point of the alias is to skip that dance.

- **Iterate with a POSIX `while read` loop, not `xargs -r`.** BSD
  `xargs` (macOS) does not implement `-r` / `--no-run-if-empty`, and
  plain `xargs` runs the command once with no args when stdin is
  empty, which prints `git branch` usage spam. A `while read` loop
  is portable and produces clean per-branch output from
  `git branch -D`.

- **Wrap the body in `f() { …; }; f`** so positional args passed to
  the alias (`git clear-gone foo`) land on the function (and are
  ignored) rather than being appended to the final command in the
  pipeline.

## Acceptance criteria

### `home/dot_gitconfig`

- An `[alias]` section exists.
- Defines a `clear-gone` alias whose body is a `!`-prefixed shell
  command that:
  - calls `git fetch --all --prune` first,
  - lists candidates via `git for-each-ref` over `refs/heads`,
  - filters on `[gone]` in the upstream-track column,
  - deletes each match via `git branch -D` inside a portable shell
    loop (no reliance on `xargs -r`).

### `tests/test_smoke.sh`

- A new section `[spec 016 — git clear-gone alias]` asserts that
  `home/dot_gitconfig`:
  - declares `clear-gone` under `[alias]`,
  - uses `for-each-ref` (not `branch -vv`),
  - filters on the literal token `[gone]`,
  - force-deletes via `git branch -D`.

## Out of scope

- Setting `fetch.prune = true` globally. That changes the behaviour of
  every plain `git fetch` invocation and deserves its own spec.
- A confirmation prompt before deletion. The alias is supposed to be
  *quick*; a confirm is the opposite of that. A user who wants a
  dry-run can run the `git for-each-ref` line on its own.
- Skipping protected branches (`main`, `master`, …). Those branches
  will never be marked `gone` unless the upstream actually disappears,
  in which case the user wants to know rather than have it silently
  hidden.
- Sibling branch-hygiene aliases (`prune-merged`, `cleanup`, …). Add
  per request, each in its own spec.
- Touching `CLAUDE.md` / `AGENTS.md` — this is an additive leaf-tool
  change with no new repo convention to record.

## Affected files

- `specs/016-git-clear-gone-alias.md` (new)
- `home/dot_gitconfig` (add `[alias]` section with `clear-gone`)
- `tests/test_smoke.sh` (one new assertion block for the alias)
