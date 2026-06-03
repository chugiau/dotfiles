# 037 - gcloud via mise

## Intent

Opening a login terminal can print:

```text
mise ERROR No version is set for shim: gcloud
Set a global default version with one of the following:
mise use -g gcloud@566.0.0
```

The local machine already has a mise `gcloud` install and shim, but the dotfiles
managed mise manifest does not declare an active `gcloud` version. Any startup
hook, completion, IDE integration, or shell plugin that executes `gcloud` then
hits the shim and fails before the prompt is usable.

Manage `gcloud` the same way as the other user-facing CLIs in
`home/dot_config/mise/config.toml`. Adding it to `[tools]` makes the generated
`~/.config/mise/config.toml` provide the active version, so the existing shim can
resolve without requiring an out-of-band `mise use -g` command.

## Acceptance criteria

- `home/dot_config/mise/config.toml` declares `gcloud = "latest"` under
  `[tools]`.
- `tests/test_smoke.sh` asserts the mise manifest declares `gcloud`.
- `sh tests/test_smoke.sh` passes from the repo root.

## Out of scope

- Installing Google Cloud account credentials or running `gcloud init`.
- Generating `gcloud` shell completions.
- Removing stale user-local mise installs or shims; once the manifest declares
  `gcloud`, those shims have an active version again.
- Pinning a specific Google Cloud CLI version. This repo uses `latest` for most
  workstation CLIs so `dotfiles update` can ride normal CLI releases.

## Affected files

- `specs/037-gcloud-via-mise.md`
- `home/dot_config/mise/config.toml`
- `tests/test_smoke.sh`
