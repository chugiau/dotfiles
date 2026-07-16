# statusline-windows/Core.ps1 - colours, formatters, width helpers.
#
# Dot-sourced by the statusline entrypoint into its script scope, mirroring
# home/dot_claude/statusline/core.sh. Pure helpers, no I/O, no side effects
# beyond defining functions and ANSI-escape constants.

# ANSI colour escapes (identical codes to core.sh's bash constants).
$Green = "`e[0;32m"
$Red = "`e[0;31m"
$Orange = "`e[0;33m"
$Yellow = "`e[1;33m"
$Magenta = "`e[0;35m"
$Cyan = "`e[0;36m"
$Reset = "`e[0m"
$Dim = "`e[2m"
$Bold = "`e[1m"

# Get-Bar <pct 0-100> <width chars> - Unicode block progress bar.
function Get-Bar {
    param(
        [int]$Pct = 0,
        [int]$Width = 10
    )

    $filled = [int][math]::Floor(($Pct * $Width + 50) / 100)
    if ($filled -gt $Width) { $filled = $Width }
    if ($filled -lt 0) { $filled = 0 }
    $empty = $Width - $filled
    ('█' * $filled) + ('░' * $empty)
}

# Get-CompactTokens <int> - 170234 -> 170.2k, 1234567 -> 1.2m, 999 -> 999.
function Get-CompactTokens {
    param([long]$N = 0)

    if ($N -ge 1000000) {
        $whole = [math]::Floor($N / 1000000)
        $frac = [math]::Floor(($N % 1000000) / 100000)
        "{0}.{1}m" -f $whole, $frac
    } elseif ($N -ge 1000) {
        $whole = [math]::Floor($N / 1000)
        $frac = [math]::Floor(($N % 1000) / 100)
        "{0}.{1}k" -f $whole, $frac
    } else {
        "$N"
    }
}

# Get-TruncatedName <name> <max> - appends "..." when length exceeds max.
function Get-TruncatedName {
    param(
        [string]$Name,
        [int]$Max = 30
    )

    if ($Name.Length -gt $Max) {
        $Name.Substring(0, $Max) + '…'
    } else {
        $Name
    }
}

# Remove-AnsiCodes <text> - strips ANSI CSI colour sequences.
function Remove-AnsiCodes {
    param([string]$Text)

    [regex]::Replace($Text, "`e\[[0-9;]*m", '')
}

# Get-VisibleWidth <text> - character count after ANSI strip.
function Get-VisibleWidth {
    param([string]$Text)

    (Remove-AnsiCodes $Text).Length
}

# Format-ActiveTime <ms> - "5m" or "1h 12m"; empty for <=0.
function Format-ActiveTime {
    param([string]$TotalDurationMs)

    $activeSecs = 0
    if ($TotalDurationMs -match '^\d+(\.\d+)?$') {
        $activeSecs = [long][math]::Floor([double]$TotalDurationMs / 1000)
    }
    if ($activeSecs -le 0) { return '' }

    $h = [math]::Floor($activeSecs / 3600)
    $m = [math]::Floor(($activeSecs % 3600) / 60)
    if ($h -gt 0) { "${h}h ${m}m" } else { "${m}m" }
}

# Format-ApiDuration <ms> - "42s", "2m 34s", "1h 3m 12s"; empty for <=0.
function Format-ApiDuration {
    param([string]$Ms)

    $totalSecs = 0
    if ($Ms -match '^\d+(\.\d+)?$') {
        $totalSecs = [long][math]::Floor([double]$Ms / 1000)
    }
    if ($totalSecs -le 0) { return '' }

    $h = [math]::Floor($totalSecs / 3600)
    $m = [math]::Floor(($totalSecs % 3600) / 60)
    $s = $totalSecs % 60
    if ($h -gt 0) { "${h}h ${m}m ${s}s" }
    elseif ($m -gt 0) { "${m}m ${s}s" }
    else { "${s}s" }
}

# Format-ResetCountdown <epoch> <unit:hm|dh> - "(resets in 2h 5m)", etc.
function Format-ResetCountdown {
    param(
        [string]$ResetAt,
        [string]$Unit = 'hm'
    )

    if ([string]::IsNullOrEmpty($ResetAt)) { return '' }

    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $secsLeft = [long][double]$ResetAt - $now
    if ($secsLeft -le 0) { return '(resetting)' }

    if ($Unit -eq 'dh') {
        $d = [math]::Floor($secsLeft / 86400)
        $h = [math]::Floor(($secsLeft % 86400) / 3600)
        "(resets in ${d}d ${h}h)"
    } else {
        $h = [math]::Floor($secsLeft / 3600)
        $m = [math]::Floor(($secsLeft % 3600) / 60)
        "(resets in ${h}h ${m}m)"
    }
}

# Get-PctColor <pct> - usage colour (low pct = green, high = red).
function Get-PctColor {
    param([int]$Pct = 0)

    if ($Pct -ge 90) { $Red }
    elseif ($Pct -ge 80) { $Orange }
    elseif ($Pct -ge 40) { $Yellow }
    else { $Green }
}

# Get-CachePctColor <pct> - cache-hit colour (high = green, low = red).
function Get-CachePctColor {
    param([int]$Pct = 0)

    if ($Pct -ge 75) { $Green }
    elseif ($Pct -ge 50) { $Yellow }
    elseif ($Pct -ge 25) { $Orange }
    else { $Red }
}
