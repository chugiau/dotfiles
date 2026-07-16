# statusline-windows/Items.ps1 - display-item emitters and the canonical
# order, mirroring home/dot_claude/statusline/items.sh.
#
# Each Add-*Item function is a no-op when the item isn't applicable, or
# appends one record to the script-scope $Items list via Add-StatuslineItem.
# Records are [PSCustomObject]@{Id;Text;Width;Priority} — a native PowerShell
# object instead of bash's \x1f-delimited string (that encoding exists only
# to work around bash 3.2's lack of associative arrays).
#
# Priorities:
#   0 - always rendered; truncated rather than dropped.
#   1 - important (folder, branch, total tokens, ctx percent).
#   2 - useful (cost, version, rate-limit bars, ahead/behind, git
#       staged/modified counts).
#   3 - nice-to-have (untracked count, line-stat diff, cache-hit pct,
#       in/out current-call tokens, CLAUDE.md count, hook count,
#       sub-agent badge, active / api / session timings).
#
# Drops are Layout.ps1's job; emitters never reorder.

$script:Items = [System.Collections.Generic.List[object]]::new()

# Add-StatuslineItem <id> <text> <visible width> <priority>
function Add-StatuslineItem {
    param(
        [string]$Id,
        [string]$Text,
        [int]$Width,
        [int]$Priority
    )

    $script:Items.Add([PSCustomObject]@{
            Id       = $Id
            Text     = $Text
            Width    = $Width
            Priority = $Priority
        })
}

# ── Emitters ─────────────────────────────────────────────────────────────
# Visible widths assume single-cell emoji render as 2 columns and ASCII as 1.

# Model: 🧠 [<model>]
function Add-ModelItem {
    $label = "🧠 ${Bold}[${script:ModelName}]${Reset}"
    $w = 2 + 1 + 1 + $script:ModelName.Length + 1
    Add-StatuslineItem 'model' $label $w 0
}

# VIM:<mode> - vim-editor mode badge; bold + colour by mode.
function Add-VimModeItem {
    if ([string]::IsNullOrEmpty($script:VimMode)) { return }
    $color = switch ($script:VimMode) {
        'INSERT' { $Green }
        'NORMAL' { $Yellow }
        { $_ -in 'VISUAL', 'VISUAL LINE' } { $Magenta }
        default { $Reset }
    }
    $label = "${Bold}${color}VIM:${script:VimMode}${Reset}"
    $w = 4 + $script:VimMode.Length
    Add-StatuslineItem 'vim_mode' $label $w 1
}

# 🤖 agent:<name> - shown when Claude is started with --agent.
function Add-AgentItem {
    if ([string]::IsNullOrEmpty($script:AgentName)) { return }
    $short = Get-TruncatedName $script:AgentName 20
    $label = "🤖 ${Cyan}agent:${short}${Reset}"
    $w = 2 + 7 + $short.Length
    Add-StatuslineItem 'agent' $label $w 1
}

# 🏷 <session_name> - shown only when the session has been renamed.
function Add-SessionNameItem {
    if ([string]::IsNullOrEmpty($script:SessionName)) { return }
    $short = Get-TruncatedName $script:SessionName 30
    $label = "🏷 ${Cyan}${short}${Reset}"
    $w = 2 + 1 + $short.Length
    Add-StatuslineItem 'session_name' $label $w 1
}

# 📁 <folder> - in worktree mode the folder is the project-root parent.
function Add-FolderItem {
    if ([string]::IsNullOrEmpty($script:ProjectDir)) { return }
    if ($script:GitWorktree) {
        $parent = Split-Path -Path $script:ProjectDir -Parent
        $name = if ($parent) { Split-Path -Path $parent -Leaf } else { '' }
        if ([string]::IsNullOrEmpty($name) -or $name -eq '.') {
            $name = Split-Path -Path $script:ProjectDir -Leaf
        }
    } else {
        $name = Split-Path -Path $script:ProjectDir -Leaf
    }
    if ([string]::IsNullOrEmpty($name)) { return }
    $label = "📁 ${Yellow}${name}${Reset}"
    $w = 2 + 1 + $name.Length
    Add-StatuslineItem 'folder' $label $w 1
}

# 🪵 <worktree>
function Add-WorktreeItem {
    if ([string]::IsNullOrEmpty($script:GitWorktree)) { return }
    $short = Get-TruncatedName $script:GitWorktree 28
    $label = "🪵 ${Cyan}${short}${Reset}"
    $w = 2 + 1 + $short.Length
    Add-StatuslineItem 'worktree' $label $w 1
}

# 🌿 git:(<branch>) - suppressed when redundant with the worktree slug.
function Add-BranchItem {
    if ([string]::IsNullOrEmpty($script:GitBranch)) { return }
    $branchRedundant = $false
    if ($script:GitWorktree) {
        if ($script:GitBranch -eq $script:GitWorktree -or
            $script:GitBranch -eq "worktree-$($script:GitWorktree)" -or
            $script:GitBranch.Contains($script:GitWorktree)) {
            $branchRedundant = $true
        }
    }
    if ($branchRedundant) { return }

    $short = if ($script:GitWorktree) { Get-TruncatedName $script:GitBranch 28 } else { Get-TruncatedName $script:GitBranch 30 }
    $label = "🌿 git:(${Magenta}${short}${Reset})"
    $w = 2 + 1 + 5 + $short.Length + 1
    Add-StatuslineItem 'branch' $label $w 1
}

function Add-AheadBehindItem {
    if ($script:GitAhead -le 0 -and $script:GitBehind -le 0) { return }
    $label = ''
    $w = 0
    if ($script:GitAhead -gt 0) {
        $label = "${Green}↑$($script:GitAhead)${Reset}"
        $w = 1 + "$($script:GitAhead)".Length
    }
    if ($script:GitBehind -gt 0) {
        if ($label) {
            $label = "$label ${Red}↓$($script:GitBehind)${Reset}"
            $w = $w + 1 + 1 + "$($script:GitBehind)".Length
        } else {
            $label = "${Red}↓$($script:GitBehind)${Reset}"
            $w = 1 + "$($script:GitBehind)".Length
        }
    }
    Add-StatuslineItem 'ahead_behind' $label $w 2
}

function Add-GitStagedItem {
    if ($script:GitStaged -le 0) { return }
    $label = "${Green}+$($script:GitStaged)${Reset}"
    $w = 1 + "$($script:GitStaged)".Length
    Add-StatuslineItem 'git_staged' $label $w 2
}

function Add-GitModifiedItem {
    if ($script:GitModified -le 0) { return }
    $label = "${Yellow}~$($script:GitModified)${Reset}"
    $w = 1 + "$($script:GitModified)".Length
    Add-StatuslineItem 'git_modified' $label $w 2
}

function Add-GitUntrackedItem {
    if ($script:GitUntracked -le 0) { return }
    $label = "${Dim}?$($script:GitUntracked)${Reset}"
    $w = 1 + "$($script:GitUntracked)".Length
    Add-StatuslineItem 'git_untracked' $label $w 3
}

function Add-GitLinesItem {
    if ($script:GitAdded -le 0 -and $script:GitDeleted -le 0) { return }
    $label = "${Green}+$($script:GitAdded)${Reset}/${Red}-$($script:GitDeleted)${Reset} lines"
    $w = 1 + "$($script:GitAdded)".Length + 1 + 1 + "$($script:GitDeleted)".Length + 6
    Add-StatuslineItem 'git_lines' $label $w 3
}

function Add-TotalTokensItem {
    $total = $script:TotalInput + $script:TotalOutput
    $s = "$total tokens"
    Add-StatuslineItem 'total_tokens' $s $s.Length 1
}

function Add-SubagentsItem {
    if ($script:SubagentCount -le 0) { return }
    $lab = if ($script:SubagentCount -gt 1) { 'sub-agents' } else { 'sub-agent' }
    $label = "${Cyan}🤖 $($script:SubagentCount) ${lab}${Reset}"
    $w = 2 + 1 + "$($script:SubagentCount)".Length + 1 + $lab.Length
    Add-StatuslineItem 'subagents' $label $w 3
}

# ⬡ <owner>/<repo> - GitHub repo identity when inside a git repo with a remote.
function Add-RepoItem {
    if ([string]::IsNullOrEmpty($script:RepoOwner) -or [string]::IsNullOrEmpty($script:RepoName)) { return }
    $s = "$($script:RepoOwner)/$($script:RepoName)"
    $label = "⬡ ${Dim}${s}${Reset}"
    $w = 2 + 1 + $s.Length
    Add-StatuslineItem 'repo' $label $w 2
}

# PR #<N> (<review_state>) - open PR for the current branch.
function Add-PrItem {
    if ([string]::IsNullOrEmpty("$($script:PrNumber)")) { return }
    switch ($script:PrReviewState) {
        'approved' { $color = $Green; $stateLabel = 'approved' }
        'changes_requested' { $color = $Red; $stateLabel = 'changes' }
        'draft' { $color = $Dim; $stateLabel = 'draft' }
        default { $color = $Yellow; $stateLabel = if ($script:PrReviewState) { $script:PrReviewState } else { 'open' } }
    }
    $s = "PR #$($script:PrNumber) ($stateLabel)"
    $label = "${color}${s}${Reset}"
    Add-StatuslineItem 'pr' $label $s.Length 2
}

# 🗃️ Context ██████░░░░
function Add-CtxBarItem {
    $color = Get-PctColor $script:CtxPct
    $bar = Get-Bar $script:CtxPct 10
    $label = "🗃️ Context ${color}${bar}${Reset}"
    $w = 2 + 9 + 10
    Add-StatuslineItem 'ctx_bar' $label $w 0
}

function Add-CtxPctItem {
    if ($null -eq $script:UsedPct) { return }
    $color = Get-PctColor $script:CtxPct
    $s = "$($script:CtxPct)%"
    Add-StatuslineItem 'ctx_pct' "${color}${s}${Reset}" $s.Length 1
}

# 🕔 Usage ██████░░░░ NN% (resets in Hh Mm)
function Add-FiveHourItem {
    if ($null -eq $script:FiveHourPct) { return }
    $pct = [int][math]::Round([double]$script:FiveHourPct, 0)
    $bar = Get-Bar $pct 10
    $resetStr = Format-ResetCountdown $script:FiveHourReset 'hm'
    $color = Get-PctColor $pct
    $label = "🕔 Usage ${color}${bar}${Reset} ${color}${pct}%${Reset}"
    $w = 2 + 7 + 10 + 1 + "$pct".Length + 1
    if ($resetStr) {
        $label = "$label $resetStr"
        $w = $w + 1 + $resetStr.Length
    }
    Add-StatuslineItem 'five_hour' $label $w 2
}

# 📅 Weekly ██████░░░░ NN% (resets in Dd Hh)
function Add-SevenDayItem {
    if ($null -eq $script:SevenDayPct) { return }
    $pct = [int][math]::Round([double]$script:SevenDayPct, 0)
    $bar = Get-Bar $pct 10
    $resetStr = Format-ResetCountdown $script:SevenDayReset 'dh'
    $color = Get-PctColor $pct
    $label = "📅 Weekly ${color}${bar}${Reset} ${color}${pct}%${Reset}"
    $w = 2 + 8 + 10 + 1 + "$pct".Length + 1
    if ($resetStr) {
        $label = "$label $resetStr"
        $w = $w + 1 + $resetStr.Length
    }
    Add-StatuslineItem 'seven_day' $label $w 2
}

function Add-VersionItem {
    if ([string]::IsNullOrEmpty($script:StatuslineVersion)) { return }
    $s = "current: $($script:StatuslineVersion)"
    Add-StatuslineItem 'version' $s $s.Length 2
}

function Add-ClaudeMdItem {
    $s = "$($script:ClaudeMdCount) CLAUDE.md"
    Add-StatuslineItem 'claude_md' $s $s.Length 3
}

function Add-HooksItem {
    $label = "🪝 $($script:HooksCount) hooks"
    $w = 2 + 1 + "$($script:HooksCount)".Length + 6
    Add-StatuslineItem 'hooks' $label $w 3
}

function Add-CachePctItem {
    if ($null -eq $script:CurInput) { return }
    $totalForCache = $script:CurInput + $script:CurCacheWrite + $script:CurCacheRead
    $hitPct = 0
    if ($totalForCache -gt 0) { $hitPct = [int][math]::Floor(($script:CurCacheRead * 100) / $totalForCache) }
    $color = Get-CachePctColor $hitPct
    $label = "cache: ${color}${hitPct}%${Reset}"
    $w = 7 + "$hitPct".Length + 1
    Add-StatuslineItem 'cache_pct' $label $w 3
}

function Add-InOutItem {
    if ($null -eq $script:CurInput) { return }
    $inFmt = Get-CompactTokens $script:CurInput
    $outFmt = Get-CompactTokens ($script:CurOutput ?? 0)
    $s = "in: $inFmt out: $outFmt"
    Add-StatuslineItem 'in_out' $s $s.Length 3
}

function Add-CostItem {
    if ([string]::IsNullOrEmpty($script:CostFormatted)) { return }
    $label = "💰 $($script:CostFormatted)"
    $w = 2 + 1 + $script:CostFormatted.Length
    Add-StatuslineItem 'cost' $label $w 2
}

function Add-ActiveTimeItem {
    if ([string]::IsNullOrEmpty($script:ActiveTimeStr)) { return }
    $label = "⚡ $($script:ActiveTimeStr)"
    $w = 2 + 1 + $script:ActiveTimeStr.Length
    Add-StatuslineItem 'active_time' $label $w 3
}

function Add-ApiDurationItem {
    if ([string]::IsNullOrEmpty($script:ApiDurationStr)) { return }
    $label = "⏱ $($script:ApiDurationStr)"
    $w = 2 + 1 + $script:ApiDurationStr.Length
    Add-StatuslineItem 'api_duration' $label $w 3
}

function Add-SessionMinsItem {
    if ($null -eq $script:SessionMins -or $script:SessionMins -le 0) { return }
    $label = "🕐 $($script:SessionMins)m"
    $w = 2 + 1 + "$($script:SessionMins)".Length + 1
    Add-StatuslineItem 'session_mins' $label $w 3
}

# Invoke-EmitAll - invoked by the entrypoint after data has been populated.
# Calls every Add-*Item in canonical left-to-right order. Drops are
# Layout.ps1's job; this list defines the ordering only.
function Invoke-EmitAll {
    $script:Items = [System.Collections.Generic.List[object]]::new()

    Add-ModelItem
    Add-VimModeItem
    Add-AgentItem
    Add-SessionNameItem
    Add-FolderItem
    Add-WorktreeItem
    Add-BranchItem
    Add-AheadBehindItem
    Add-GitStagedItem
    Add-GitModifiedItem
    Add-GitUntrackedItem
    Add-GitLinesItem
    Add-TotalTokensItem
    Add-SubagentsItem
    Add-RepoItem
    Add-PrItem
    Add-CtxBarItem
    Add-CtxPctItem
    Add-FiveHourItem
    Add-SevenDayItem
    Add-VersionItem
    Add-EffortItem
    Add-OutputStyleItem
    Add-ThinkingItem
    Add-ClaudeMdItem
    Add-HooksItem
    Add-CachePctItem
    Add-InOutItem
    Add-CostItem
    Add-ActiveTimeItem
    Add-ApiDurationItem
    Add-SessionMinsItem
}

# ✦ effort:<level> - colour-coded reasoning-effort setting.
function Add-EffortItem {
    if ([string]::IsNullOrEmpty($script:EffortLevel)) { return }
    $color = switch ($script:EffortLevel) {
        'low' { $Green }
        'medium' { $Yellow }
        'high' { $Orange }
        { $_ -in 'xhigh', 'max' } { $Red }
        default { $Reset }
    }
    $label = "✦ effort:${color}$($script:EffortLevel)${Reset}"
    $w = 2 + 8 + $script:EffortLevel.Length
    Add-StatuslineItem 'effort' $label $w 2
}

# ✎ <output_style_name> - active output style, suppressed for "default".
function Add-OutputStyleItem {
    if ([string]::IsNullOrEmpty($script:OutputStyleName)) { return }
    if ($script:OutputStyleName.ToLowerInvariant() -eq 'default') { return }
    $label = "✎ $($script:OutputStyleName)"
    $w = 2 + 1 + $script:OutputStyleName.Length
    Add-StatuslineItem 'output_style' $label $w 3
}

# 💭 thinking - shown only when extended thinking is enabled.
function Add-ThinkingItem {
    if (-not $script:ThinkingEnabled) { return }
    $label = '💭 thinking'
    $w = 2 + 9
    Add-StatuslineItem 'thinking' $label $w 3
}
