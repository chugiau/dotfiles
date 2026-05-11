# 029 — AI agent sensitive file guard

## Intent

Prevent AI agents managed by these dotfiles from reading local secret material.
The guard must stop direct requests for SSH private-key material and env-like
files before their contents can enter a model request or a transcript.

Claude Code is the configured agent surface in this repository, so this spec
targets `~/.claude/settings.json` and a local Claude hook. The hook handles
prompt-time and tool-time checks; permission deny rules and sandboxing provide
the filesystem policy that catches built-in file tools and Bash subprocesses.

## Acceptance criteria

- `chezmoi apply` installs an executable Claude hook under `~/.claude/hooks/`
  that blocks prompts or tool calls referencing sensitive file targets.
- The hook blocks `UserPromptSubmit` input that references `~/.ssh/`,
  `.env`, `.env.*`, `.envrc`, or `*.env*` before Claude processes the prompt.
- The hook blocks `PreToolUse` calls for common file-reading paths, including
  `Read`, `Glob`, `Grep`, `Bash`, `Edit`, `MultiEdit`, `Write`, and `Agent`,
  when their JSON input references those same sensitive targets.
- The hook never prints the submitted prompt, tool input, or matched sensitive
  path in its block reason.
- The Claude settings merge preserves unrelated existing settings while
  idempotently adding:
  - `permissions.deny` entries for `~/.ssh/**` and env-like files.
  - `permissions.disableBypassPermissionsMode = "disable"`.
  - `sandbox.enabled = true` and `sandbox.failIfUnavailable = true`.
  - `UserPromptSubmit` and `PreToolUse` hook entries pointing at the managed
    sensitive-file guard script.
- The smoke test renders the settings merge script and exercises missing,
  existing, and already-up-to-date settings files.
- The smoke test executes the hook against representative allowed and blocked
  `UserPromptSubmit` and `PreToolUse` fixtures.

## Out of scope

- Enterprise managed settings outside the dotfiles-controlled user settings
  file.
- Codex CLI policy. This change only manages the Claude Code configuration
  already deployed by this repository.
- Content inspection of arbitrary files to distinguish SSH private keys from
  other files under `~/.ssh/`; the policy intentionally denies the whole
  directory because private keys can use arbitrary filenames.
- Allowlisting individual non-secret env files.

## Affected files

- `specs/029-ai-agent-sensitive-file-guard.md`
- `home/dot_claude/hooks/executable_sensitive-file-guard.sh`
- `home/run_onchange_after_62-claude-security.sh.tmpl`
- `tests/test_smoke.sh`
- `README.md`
- `AGENTS.md`
