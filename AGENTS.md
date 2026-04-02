# Agent Guidelines — dotfiles

## Non-Negotiable Rules

1. **TDD** — Write tests first. Red → Green → Refactor.
2. **Commit after each step** — Git commit after each completed logical unit of work. Don't batch.
3. **English only** — All code, commit messages, comments, OpenSpec artifacts, and AI-facing docs must be in English, except for user conversation.
4. **No secrets in code** — Never commit passwords, connection strings, API keys, or credentials. Use environment variables or user-secrets.

## Work Approach

- Use shell tools, CLIs, APIs, and scripts to do the work.
- Offload repetitive or high-volume work to scripts; return only the distilled result.
- Use subagents for isolation: parallel search, document digestion, exploratory analysis.
- Clarify the goal → execute → persist state → return the smallest useful summary.
