# 031 - Ignore local direnv and dotenv files

## Intent

Keep repository-local direnv and dotenv state out of version control. These
files commonly contain machine-specific or secret values, and the dotfiles repo
already treats plaintext environment files as non-committable material through
its pre-commit hook. The ignore rules should make the everyday `git status`
view match that policy before staging time.

## Acceptance criteria

- `.gitignore` ignores root and nested direnv allow files.
- `.gitignore` ignores root and nested direnv cache directories.
- `.gitignore` ignores root and nested dotenv files, including suffixed local
  variants.
- `.gitignore` keeps shareable examples and chezmoi/password-manager templates
  visible to git.
- `tests/test_smoke.sh` checks the ignore policy with `git check-ignore` so
  future edits cannot silently loosen it.

## Out of scope

- Reading, validating, or committing any local environment file contents.
- Changing the pre-commit secret scanner.
- Shipping project-specific direnv boilerplate.

## Affected files

- `specs/031-ignore-local-env-files.md`
- `.gitignore`
- `tests/test_smoke.sh`
