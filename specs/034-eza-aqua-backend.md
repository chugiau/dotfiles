# 034 - Install eza through mise aqua backend

## Intent

`mise install` fails for `eza` on native Windows when the shorthand `eza =
"latest"` resolves to `cargo:eza`. That backend requires a Rust toolchain on
PATH, but these dotfiles do not require Rust just to install the shared CLI
toolset.

Install `eza` through the `aqua:eza-community/eza` backend instead. The aqua
backend downloads the upstream release binary and does not require `cargo`.

## Acceptance criteria

- `home/dot_config/mise/config.toml` declares
  `"aqua:eza-community/eza" = "latest"` under `[tools]`.
- `home/dot_config/mise/config.toml` does not declare bare `eza = "latest"`,
  because the bare registry shorthand can resolve to `cargo:eza`.
- The smoke tests fail if `eza` is moved back to the cargo-backed shorthand.
- `README.md` documents the explicit eza backend in its mise manifest example.

## Out of scope

- Installing Rust or Cargo as part of the base dotfiles toolchain.
- Changing aliases, shell startup behavior, or completion generation for eza.
- Pinning a specific eza version.

## Affected files

- `specs/034-eza-aqua-backend.md`
- `home/dot_config/mise/config.toml`
- `tests/test_smoke.sh`
- `tests/windows_smoke.ps1`
- `README.md`
