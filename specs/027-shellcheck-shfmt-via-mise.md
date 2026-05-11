# 027 - Install ShellCheck and shfmt via mise

## Intent

`dotfiles test` already runs ShellCheck and shfmt when those binaries are
available, but a fresh machine does not currently receive them from the mise
tool manifest. This leaves the static test gates optional in practice even
after `dotfiles install`.

Manage ShellCheck and shfmt through mise so every installed checkout gets the
same shell linting and formatting tools through the existing shim path.

## Acceptance criteria

- `home/dot_config/mise/config.toml` declares `shellcheck` under `[tools]`.
- `home/dot_config/mise/config.toml` declares `shfmt` under `[tools]`.
- `tests/test_smoke.sh` fails if either mise tool declaration is removed.
- `README.md` lists ShellCheck and shfmt in the mise-managed dev tool set and
  inline `[tools]` example.
- Existing `dotfiles test` static checks continue to use `shellcheck` and
  `shfmt` when present.

## Out of scope

- Installing ShellCheck or shfmt through distro package managers.
- Changing the list of files linted or formatted by `dotfiles test`.
- Adding ShellCheck or shfmt to `bin/dotfiles doctor`; missing static tools
  already surface through the test command once mise has installed them.
- Pinning exact tool versions.

## Affected files

- `specs/027-shellcheck-shfmt-via-mise.md`
- `home/dot_config/mise/config.toml`
- `tests/test_smoke.sh`
- `README.md`
