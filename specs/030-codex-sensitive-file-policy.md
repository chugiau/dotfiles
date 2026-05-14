# 030 — Codex sensitive file policy

## Intent

Prevent Codex CLI sessions managed by these dotfiles from reading local secret
material or sending direct secret-file references into the model request or
session transcript.

The policy must cover SSH private-key material and env-like files with two
layers:

- a Codex hook that blocks prompt and tool input before Codex continues, without
  echoing the matched path; and
- a Codex filesystem permission profile that denies reads for sensitive paths
  even when a command is otherwise allowed inside the workspace sandbox.

## Acceptance criteria

- `chezmoi apply` installs an executable Codex hook under `~/.codex/hooks/`
  that blocks direct references to sensitive file targets.
- The hook blocks `UserPromptSubmit` input that asks Codex to read, show,
  edit, or otherwise access path-like sensitive file targets matching `.env`,
  `.env.*`, `.envrc`, or `*.env*` before the prompt continues.
- The hook treats SSH paths as an allowlist: `~/.ssh/config`,
  `~/.ssh/config.d/*`, and public keys under `~/.ssh/*.pub` are allowed, while
  directory reads of `~/.ssh` and any other `~/.ssh/*` target are blocked.
- The hook allows prompts that discuss those names as plain text without asking
  Codex to access the corresponding files.
- The hook blocks `PreToolUse` input for common read or edit paths, including
  `Bash`, `Read`, `Glob`, `Grep`, `apply_patch`, `Edit`, `Write`, and MCP tool
  calls, when structured path fields or command arguments reference those same
  path-like sensitive targets. Search patterns or prose that merely mention a
  sensitive basename are allowed when they are not file access targets.
- The hook never prints the submitted prompt, tool input, or matched sensitive
  path in its block reason.
- The smoke test creates temporary fake SSH private-key and env-like files with
  canary content, then verifies blocked hook output does not include the fake
  path or canary content. Tests must never reference real user private keys or
  real env files.
- `chezmoi apply` idempotently enables Codex hooks in `~/.codex/config.toml`
  with `[features].hooks = true` while preserving unrelated existing settings.
- `chezmoi apply` removes or migrates the deprecated
  `[features].codex_hooks` setting so Codex does not warn about deprecated
  configuration.
- `chezmoi apply` idempotently writes `~/.codex/hooks.json` with
  `UserPromptSubmit` and `PreToolUse` entries pointing at the managed hook while
  preserving unrelated existing hook entries.
- `chezmoi apply` idempotently configures a Codex filesystem permission profile
  that allows the SSH config allowlist while denying other `~/.ssh/*` targets,
  home-level env files, and env-like files under project roots.
- The smoke test executes the hook against representative allowed and blocked
  `UserPromptSubmit` and `PreToolUse` fixtures, including the fake secret-file
  fixtures and false-positive cases where sensitive basenames appear only as
  text or search patterns.
- The smoke test renders the Codex security merge script and exercises missing,
  existing, and already-up-to-date config and hook files.

## Out of scope

- Enterprise-managed Codex requirements under `/etc/codex/requirements.toml`;
  this repository manages user-level dotfiles, not system policy.
- Content-inspecting SSH files to distinguish private keys from other files.
  Private keys can use arbitrary filenames, so the policy uses a small
  allowlist instead of reading candidate file contents.
- Allowlisting individual non-secret env files.
- Preventing a user from deliberately launching Codex with
  `--dangerously-bypass-approvals-and-sandbox` or overriding the managed
  user-level config manually.

## Affected files

- `specs/030-codex-sensitive-file-policy.md`
- `home/dot_codex/hooks/executable_sensitive-file-guard.sh`
- `home/run_onchange_after_63-codex-security.sh.tmpl`
- `tests/test_smoke.sh`
- `bin/dotfiles`
- `README.md`
- `AGENTS.md`
