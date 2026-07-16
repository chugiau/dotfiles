# 041 - Native Windows statusline port

## Intent

The Claude Code statusline (spec 021's item-list + packer architecture, in
`home/dot_claude/statusline/*.sh` and `executable_statusline-command.sh`) is
bash + `jq`. Native Windows (spec 033) has no bash and no wiring for it:
`run_onchange_after_60-claude-statusline.sh.tmpl` is Unix-only (ignored on
Windows by `home/.chezmoiignore`), so `~/.claude/settings.json` never gets a
`statusLine` block on a native Windows checkout, and even if it did, the bash
entrypoint has nothing to run it. This spec ports the spec-021 architecture to
native PowerShell 7+ (`pwsh` — the shell this repo already standardizes native
Windows on, per spec 033's `Documents/PowerShell` profile dispatch and `mise
activate pwsh`) and wires it into `settings.json` the same way the Unix path
does.

Two upstream facts (confirmed against Claude Code's own statusline docs)
change the port instead of it being a blind line-for-line translation:

- Claude Code sets `$env:COLUMNS`/`$env:LINES` to the real terminal size
  before it spawns the statusline subprocess, specifically because console
  APIs cannot see the terminal from inside a captured-output subprocess. This
  makes bash's elaborate `/proc/<ppid>/fd/*` pty-walk (spec 022) unnecessary
  here — the Windows port only needs to read `$env:COLUMNS`.
- On Windows, Claude Code may route the `statusLine.command` string through
  Git Bash when it's installed. Git Bash treats unescaped backslashes as
  escape characters, so a literal `C:\Users\...` command path silently loses
  its separators. The wiring script must emit a forward-slash path.

## Acceptance criteria

### Architecture

- New directory `home/dot_claude/statusline-windows/` holds `Core.ps1`,
  `Data.ps1`, `Width.ps1`, `Items.ps1`, `Layout.ps1` — a one-to-one purpose
  mirror of `core.sh`/`data.sh`/`width.sh`/`items.sh`/`layout.sh`. Item
  records are `[PSCustomObject]` with `Id`/`Text`/`Width`/`Priority`
  properties, not the bash version's `\x1f`-delimited encoded strings — that
  encoding exists only to work around bash 3.2's lack of associative arrays,
  which does not apply to PowerShell.
- `home/dot_claude/statusline-command.ps1` (new) is the entrypoint: dot-
  sources the 5 modules, reads stdin JSON, populates fields, emits items,
  detects width, packs, renders — mirrors the bash entrypoint's `main()`.
- Item set, priorities (0-3), and canonical left-to-right emit order are
  identical to spec 021's table; this is a port, not a redesign.

### Width detection (`Width.ps1`)

- `Get-StatuslineColumns`: `$env:CLAUDE_STATUSLINE_COLS` (test escape hatch)
  -> `$env:COLUMNS` (set by Claude Code before launch, per upstream docs) ->
  literal `80`. No `[Console]::WindowWidth` call and no parent-process walk —
  see Intent.

### JSON + data extraction (`Data.ps1`)

- `Get-StatuslineFields` reads stdin via `$input | Out-String |
  ConvertFrom-Json` (the pattern Claude Code's own Windows statusline docs
  use), wrapped in try/catch so malformed/empty stdin degrades gracefully
  instead of crashing, and exposes the same ~30 fields as `extract_fields`
  (model, cwd, project_dir, transcript_path, session_id, git_worktree,
  context-window usage, rate limits, cost/duration, effort/output-style/
  thinking/vim-mode, session_name, repo owner/name, PR number/state, agent
  name) using PS7 `??` chaining for jq's `// default` idiom.
- `Get-GitInfo` shells out to the same `git -C <dir> status --porcelain` /
  `diff --numstat` / `rev-list --left-right --count HEAD...@{u}` commands as
  `collect_git_info`, parsed with PowerShell string ops.
- `Get-SessionMinutes` reads `(Get-Item $transcriptPath).CreationTimeUtc`
  directly — NTFS exposes real file creation time, replacing bash's
  `file_btime` stat/JSONL-timestamp fallback chain with one line.
- `Get-ClaudeMdCount`, `Get-HooksCount`, `Get-SubagentCount` mirror
  `count_claude_md`/`count_hooks`/`count_subagents`: recursive `CLAUDE.md`
  count via `Get-ChildItem -Recurse -Depth 5`, hooks count via
  `ConvertFrom-Json` on `~/.claude/settings.json` (falling back to counting
  hook script files), subagent counter read from
  `$env:TEMP\claude-subagents-<session_id>` (absent file -> 0, same as bash;
  no hook in this repo writes this file on either platform).

### Rendering (`Core.ps1`, `Layout.ps1`)

- Same raw ANSI CSI escapes as `core.sh` (identical colour codes), plus the
  same `Get-Bar`, `Get-CompactTokens`, `Get-TruncatedName`, `Get-PctColor`,
  `Get-CachePctColor`, and time formatters
  (`Format-ActiveTime`/`Format-ApiDuration`/`Format-ResetCountdown`).
  `statusline-command.ps1` sets `$PSStyle.OutputRendering = 'Ansi'` once at
  startup so the escapes survive Claude Code's stdout capture (Microsoft's
  `about_ANSI_Terminals` guidance: explicit `Ansi` mode is recommended for
  output consumed outside the PowerShell host).
- `Invoke-LayoutPack`/`Invoke-LayoutRender` port the same drop-then-greedy-
  wrap algorithm: max 5 lines, priority-0 items never dropped, rightmost
  highest-priority item dropped first when the plan overflows, ANSI-aware
  `…` truncation on any surviving overflowed line.

### Wiring (`home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl`, new)

- Windows-only (`$IsWindows` guard, matching `05`/`11`/`12`).
- Idempotently merges `{type:"command", command:"pwsh -NoProfile -NoLogo
  -File <forward-slash path>", padding:0}` into `~/.claude/settings.json`'s
  `statusLine` key using `ConvertFrom-Json`/`ConvertTo-Json` — no `jq`
  dependency, matching the "don't assume POSIX tools" spirit of the existing
  Windows run scripts.
- Skips the write when the desired block already matches (same idempotency
  as the Unix version). A failed write is caught and turned into
  `Write-Warning`, matching `11`/`12`'s error-handling convention, instead of
  aborting `chezmoi apply`.
- Command path uses forward slashes (see Intent).

### `home/.chezmoiignore`

- Non-Windows branch: ignore `13-claude-statusline-windows.ps1` (run-script
  target name, matching the `05`/`11`/`12` bare-name entries) plus
  `.claude/statusline-windows/` and `.claude/statusline-command.ps1` (target
  paths, matching the `.config/dotfiles/powershell/` style entry).
- Windows branch: also ignore the existing bash-only `.claude/statusline/`
  and `.claude/statusline-command.sh` — they are dead weight without bash and
  were simply never split out before this spec.

### Tests (`tests/windows_smoke.ps1`)

- Structural: the entrypoint and all 5 module files exist and PowerShell-
  parse (extend the existing `[structure]`/`[PowerShell parse]` loops).
- `[claude statusline]` section: wiring script exists, parses, is Windows-
  only, contains no `jq` invocation, builds a forward-slash command path.
- `[chezmoi platform split]` section: extend to assert `.chezmoiignore`
  ignores the new Windows-only paths on non-Windows, and the bash statusline
  paths on Windows.
- Behavioural: pipe the same fixture JSON shape used by `test_smoke.sh`'s
  spec-021 block through `pwsh -NoProfile -File statusline-command.ps1` with
  `CLAUDE_STATUSLINE_COLS` set to 300 / 80 / 40 and assert, matching the bash
  behavioural assertions:
  - 300 -> exactly 1 line containing the model name and `Context`.
  - 80 -> 2-5 lines containing the model name and `Context`.
  - 40 -> 1-5 lines containing the model name, and the P2 `Weekly` bar
    dropped.
- No changes to `tests/test_smoke.sh` — the new files are Windows-only and
  ignored on POSIX via `.chezmoiignore`.

### `README.md`

- Add `home/dot_claude/statusline-windows/`, `statusline-command.ps1`, and
  `run_onchange_after_13-claude-statusline-windows.ps1.tmpl` to the tree
  diagram; note that native Windows gets its own PowerShell statusline, wired
  the same way as the Unix path.

## Out of scope

- Reimplementing spec 022's `/proc`-based pty-walk on Windows — Claude Code's
  documented `$env:COLUMNS` behaviour makes it unnecessary (see Intent). If
  real-world use later shows `$env:COLUMNS` is unreliable under some Windows
  terminal host, that is a follow-up spec.
- wcwidth-correct CJK/emoji width counting — same carve-out as spec 021.
- Per-item user configuration — same carve-out as spec 021.
- Windows PowerShell 5.1 (`powershell.exe`) compatibility — native Windows in
  this repo is PowerShell 7+ (`pwsh`) only; the script may use PS7-only
  syntax (`??`).
- Populating the sub-agent counter file — no hook in this repo writes it on
  either platform.
- Changing the Unix statusline's behaviour or wiring — `statusline/*.sh`,
  `executable_statusline-command.sh`, and
  `run_onchange_after_60-claude-statusline.sh.tmpl` are unchanged other than
  the `.chezmoiignore` cleanup noted above.

## Affected files

- `specs/041-windows-statusline-port.md` (new)
- `home/dot_claude/statusline-windows/Core.ps1` (new)
- `home/dot_claude/statusline-windows/Data.ps1` (new)
- `home/dot_claude/statusline-windows/Width.ps1` (new)
- `home/dot_claude/statusline-windows/Items.ps1` (new)
- `home/dot_claude/statusline-windows/Layout.ps1` (new)
- `home/dot_claude/statusline-command.ps1` (new)
- `home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl` (new)
- `home/.chezmoiignore`
- `tests/windows_smoke.ps1`
- `README.md`
