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
- The hook blocks `UserPromptSubmit` input that references `~/.ssh/`, `.env`,
  `.env.*`, `.envrc`, or `*.env*` before the prompt continues.
- The hook blocks `PreToolUse` input for common read or edit paths, including
  `Bash`, `Read`, `Glob`, `Grep`, `apply_patch`, `Edit`, `Write`, and MCP tool
  calls, when the JSON input references those same sensitive targets.
- The hook never prints the submitted prompt, tool input, or matched sensitive
  path in its block reason.
- The smoke test creates temporary fake SSH private-key and env-like files with
  canary content, then verifies blocked hook output does not include the fake
  path or canary content. Tests must never reference real user private keys or
  real env files.
- `chezmoi apply` idempotently enables Codex hooks in `~/.codex/config.toml`
  while preserving unrelated existing settings.
- `chezmoi apply` idempotently writes `~/.codex/hooks.json` with
  `UserPromptSubmit` and `PreToolUse` entries pointing at the managed hook while
  preserving unrelated existing hook entries.
- `chezmoi apply` idempotently configures a Codex filesystem permission profile
  that denies reads for `~/.ssh/**`, home-level env files, and env-like files
  under project roots.
- The smoke test executes the hook against representative allowed and blocked
  `UserPromptSubmit` and `PreToolUse` fixtures, including the fake secret-file
  fixtures.
- The smoke test renders the Codex security merge script and exercises missing,
  existing, and already-up-to-date config and hook files.

## Out of scope

- Enterprise-managed Codex requirements under `/etc/codex/requirements.toml`;
  this repository manages user-level dotfiles, not system policy.
- Distinguishing SSH private keys from other files under `~/.ssh/`; the policy
  denies the whole directory because private keys can use arbitrary filenames.
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
