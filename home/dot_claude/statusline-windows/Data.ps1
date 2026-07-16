# statusline-windows/Data.ps1 - JSON field extraction, git inspection,
# transcript timing, and counters. Populates script-scope variables read by
# Items.ps1's emitters, mirroring home/dot_claude/statusline/data.sh.
#
# Set-StatuslineFields expects an already-parsed JSON object (see
# statusline-command.ps1 for the `$input | Out-String | ConvertFrom-Json`
# read, which only works correctly at the top level of a piped script).

# Set-StatuslineFields <parsed JSON object> - populate script-scope globals
# from the Claude Code statusline stdin payload. Missing fields default to
# empty string, 0, or $null; emitters treat empty/$null as "skip".
function Set-StatuslineFields {
    param($Data)

    $script:ModelName = $Data.model.display_name ?? 'Unknown'
    $script:Cwd = $Data.workspace.current_dir ?? $Data.cwd ?? ''
    $script:StatuslineVersion = $Data.version ?? ''
    $script:ProjectDir = $Data.workspace.project_dir ?? $Data.workspace.current_dir ?? $Data.cwd ?? ''
    $script:TranscriptPath = $Data.transcript_path ?? ''
    $script:SessionId = $Data.session_id ?? ''
    $script:GitWorktree = $Data.workspace.git_worktree ?? ''

    $script:UsedPct = $Data.context_window.used_percentage
    $script:TotalInput = [long]($Data.context_window.total_input_tokens ?? 0)
    $script:TotalOutput = [long]($Data.context_window.total_output_tokens ?? 0)
    $script:CurInput = $Data.context_window.current_usage.input_tokens
    $script:CurOutput = $Data.context_window.current_usage.output_tokens
    $script:CurCacheWrite = [long]($Data.context_window.current_usage.cache_creation_input_tokens ?? 0)
    $script:CurCacheRead = [long]($Data.context_window.current_usage.cache_read_input_tokens ?? 0)

    $script:FiveHourPct = $Data.rate_limits.five_hour.used_percentage
    $script:FiveHourReset = $Data.rate_limits.five_hour.resets_at
    $script:SevenDayPct = $Data.rate_limits.seven_day.used_percentage
    $script:SevenDayReset = $Data.rate_limits.seven_day.resets_at

    $script:TotalDurationMs = $Data.cost.total_duration_ms
    $script:TotalApiDurationMs = $Data.cost.total_api_duration_ms
    $script:TotalCost = $Data.cost.total_cost_usd

    $script:EffortLevel = $Data.effort.level ?? ''
    $script:OutputStyleName = $Data.output_style.name ?? ''
    $script:ThinkingEnabled = ($Data.thinking.enabled -eq $true)
    $script:VimMode = $Data.vim.mode ?? ''

    $script:SessionName = $Data.session_name ?? ''
    $script:RepoOwner = $Data.workspace.repo.owner ?? ''
    $script:RepoName = $Data.workspace.repo.name ?? ''
    $script:PrNumber = $Data.pr.number
    $script:PrReviewState = $Data.pr.review_state ?? ''
    $script:AgentName = $Data.agent.name ?? ''
}

# Set-GitInfo <dir> - populate GitBranch, GitStaged, GitModified,
# GitUntracked, GitAdded, GitDeleted, GitAhead, GitBehind script-scope
# variables.
function Set-GitInfo {
    param([string]$Dir)

    $script:GitBranch = ''
    $script:GitStaged = 0
    $script:GitModified = 0
    $script:GitUntracked = 0
    $script:GitAdded = 0
    $script:GitDeleted = 0
    $script:GitAhead = 0
    $script:GitBehind = 0

    if ([string]::IsNullOrEmpty($Dir) -or -not (Get-Command git -ErrorAction SilentlyContinue)) {
        return
    }

    $branch = (& git -C $Dir --no-optional-locks symbolic-ref --short HEAD 2>$null)
    if (-not $branch) {
        $branch = (& git -C $Dir --no-optional-locks rev-parse --short HEAD 2>$null)
    }
    $script:GitBranch = "$branch"
    if ([string]::IsNullOrEmpty($script:GitBranch)) { return }

    $statusLines = @(& git -C $Dir --no-optional-locks status --porcelain 2>$null)
    foreach ($line in $statusLines) {
        if ([string]::IsNullOrEmpty($line) -or $line.Length -lt 2) { continue }
        $x = $line[0]
        $y = $line[1]
        if ($x -in 'A', 'M', 'D', 'R', 'C') { $script:GitStaged++ }
        if ($y -in 'M', 'D') { $script:GitModified++ }
        if ($line.Substring(0, 2) -eq '??') { $script:GitUntracked++ }
    }

    if ($script:GitStaged -gt 0 -or $script:GitModified -gt 0) {
        $numstatLines = @()
        $numstatLines += @(& git -C $Dir --no-optional-locks diff --numstat 2>$null)
        $numstatLines += @(& git -C $Dir --no-optional-locks diff --cached --numstat 2>$null)
        foreach ($line in $numstatLines) {
            if ([string]::IsNullOrEmpty($line)) { continue }
            $parts = $line -split "`t"
            if ($parts.Count -ge 2) {
                if ($parts[0] -match '^\d+$') { $script:GitAdded += [int]$parts[0] }
                if ($parts[1] -match '^\d+$') { $script:GitDeleted += [int]$parts[1] }
            }
        }
    }

    $abRaw = "$(& git -C $Dir --no-optional-locks rev-list --left-right --count 'HEAD...@{u}' 2>$null)"
    if (-not [string]::IsNullOrEmpty($abRaw)) {
        $abParts = $abRaw -split "`t"
        if ($abParts.Count -ge 2) {
            if ($abParts[0] -match '^\d+$') { $script:GitAhead = [int]$abParts[0] }
            if ($abParts[1] -match '^\d+$') { $script:GitBehind = [int]$abParts[1] }
        }
    }
}

# Get-SessionMinutes <transcript path> - whole minutes since the transcript
# file was created. NTFS exposes real creation time directly, so this needs
# none of core.sh's file_btime stat/JSONL-timestamp fallback chain.
function Get-SessionMinutes {
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return 0
    }

    try {
        $created = (Get-Item -LiteralPath $Path -ErrorAction Stop).CreationTimeUtc
    } catch {
        return 0
    }

    $elapsed = [int][math]::Floor(([DateTime]::UtcNow - $created).TotalMinutes)
    if ($elapsed -lt 0) { $elapsed = 0 }
    $elapsed
}

# Get-ClaudeMdCount <project dir> - number of CLAUDE.md files within 5 levels.
function Get-ClaudeMdCount {
    param([string]$Dir)

    if ([string]::IsNullOrEmpty($Dir) -or -not (Test-Path -LiteralPath $Dir -PathType Container)) {
        return 0
    }

    @(Get-ChildItem -LiteralPath $Dir -Filter 'CLAUDE.md' -File -Recurse -Depth 5 -ErrorAction SilentlyContinue).Count
}

# Get-HooksCount - number of hook entries declared in settings.json
# (preferred) or hook script files under the hooks dir as a fallback.
function Get-HooksCount {
    $claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
    $hooksDir = Join-Path $claudeDir 'hooks'
    $settingsFile = Join-Path $claudeDir 'settings.json'

    if (Test-Path -LiteralPath $settingsFile -PathType Leaf) {
        try {
            $settings = Get-Content -LiteralPath $settingsFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            $count = 0
            if ($settings.hooks) {
                foreach ($eventProp in $settings.hooks.PSObject.Properties) {
                    foreach ($matcher in @($eventProp.Value)) {
                        $count += @($matcher.hooks).Count
                    }
                }
            }
            return $count
        } catch {
            # Fall through to the hooks-directory fallback below.
        }
    }

    if (Test-Path -LiteralPath $hooksDir -PathType Container) {
        return @(Get-ChildItem -LiteralPath $hooksDir -Recurse -Depth 3 -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in '.ps1', '.js', '.ts', '.py', '.sh' }).Count
    }

    0
}

# Get-SubagentCount <session_id> - sub-agent counter file written by an
# external hook (none exists in this repo yet on either platform; absent
# file just means 0, matching count_subagents in data.sh).
function Get-SubagentCount {
    param([string]$SessionId)

    if ([string]::IsNullOrEmpty($SessionId) -or $SessionId -notmatch '^[a-zA-Z0-9_-]+$') {
        return 0
    }

    $counterFile = Join-Path $env:TEMP "claude-subagents-$SessionId"
    if (-not (Test-Path -LiteralPath $counterFile -PathType Leaf)) {
        return 0
    }

    $raw = (Get-Content -LiteralPath $counterFile -Raw -ErrorAction SilentlyContinue)
    if ($raw -and $raw.Trim() -match '^\d+$') {
        [int]$raw.Trim()
    } else {
        0
    }
}
