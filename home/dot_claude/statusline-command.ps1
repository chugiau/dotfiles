# statusline-command.ps1 - Claude Code statusline entrypoint (native
# Windows, PowerShell 7+).
#
# Reads a JSON payload from stdin (provided by Claude Code), populates a
# flat list of display items, detects the terminal width, and lets the
# packer wrap them into 1-5 lines while dropping low-priority items when
# space is tight. Mirrors executable_statusline-command.sh's main().
#
# See specs/041-windows-statusline-port.md for the architecture and the
# rationale for the Windows-specific deviations (no /proc pty-walk, no jq,
# forward-slash command path).

$ErrorActionPreference = 'Stop'

# Claude Code spawns this script with stdout captured through a redirected
# pipe, not a real console. When output is redirected, PowerShell's console
# host writes pipeline output through [Console]::Out using
# [Console]::OutputEncoding - the process's OEM/ANSI code page (e.g. cp950
# on Traditional Chinese Windows), not UTF-8 - so every emoji and
# box-drawing glyph the packer emits (🧠 📁 🌿 █ ░ ...) gets replaced with
# '?' on write. [Console]::OutputEncoding's setter calls a Win32 console API
# that requires an attached console and can throw when Claude Code launches
# this script with none; rewrapping the raw stdout handle directly sidesteps
# that and guarantees UTF-8 bytes regardless of how the process was spawned.
# Interactive runs in a real terminal are unaffected: PowerShell writes
# directly to the console via WriteConsoleW (UTF-16, no code page involved)
# whenever output isn't redirected, so this only changes the captured-pipe
# path Claude Code actually uses.
try {
    $Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $stdoutWriter = [System.IO.StreamWriter]::new([Console]::OpenStandardOutput(), $Utf8NoBom)
    $stdoutWriter.AutoFlush = $true
    [Console]::SetOut($stdoutWriter)
} catch {
    # Best effort: fall back to the host's default stdout encoding rather
    # than aborting the whole statusline.
}

$PSStyle.OutputRendering = 'Ansi'

. (Join-Path $PSScriptRoot 'statusline-windows/Core.ps1')
. (Join-Path $PSScriptRoot 'statusline-windows/Data.ps1')
. (Join-Path $PSScriptRoot 'statusline-windows/Width.ps1')
. (Join-Path $PSScriptRoot 'statusline-windows/Items.ps1')
. (Join-Path $PSScriptRoot 'statusline-windows/Layout.ps1')

$raw = $input | Out-String
$data = [PSCustomObject]@{}
if (-not [string]::IsNullOrWhiteSpace($raw)) {
    try {
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $data = [PSCustomObject]@{}
    }
}

Set-StatuslineFields $data
Set-GitInfo $script:Cwd

$script:SessionMins = Get-SessionMinutes $script:TranscriptPath
$script:ActiveTimeStr = Format-ActiveTime "$($script:TotalDurationMs)"
$script:ApiDurationStr = Format-ApiDuration "$($script:TotalApiDurationMs)"
$script:SubagentCount = Get-SubagentCount $script:SessionId
$script:ClaudeMdCount = Get-ClaudeMdCount $script:ProjectDir
$script:HooksCount = Get-HooksCount

$script:CtxPct = 0
if ($null -ne $script:UsedPct) {
    $script:CtxPct = [int][math]::Round([double]$script:UsedPct, 0)
}

$script:CostFormatted = ''
if ($null -ne $script:TotalCost -and [double]$script:TotalCost -ne 0) {
    $script:CostFormatted = '$' + ([double]$script:TotalCost).ToString('F4', [System.Globalization.CultureInfo]::InvariantCulture)
}

Invoke-EmitAll

$cols = Get-StatuslineColumns

Invoke-LayoutPack $cols
Invoke-LayoutRender $cols
