# statusline-windows/Width.ps1 - terminal-column detection.
#
# Claude Code captures the statusline script's stdout instead of connecting
# it to the terminal, so console-width APIs cannot see the real terminal
# size from inside the script. Claude Code's own docs say it sets $env:COLUMNS
# / $env:LINES to the terminal dimensions before launching the script, so
# unlike the bash port (which has to walk /proc/<ppid>/fd/* to find an
# ancestor's pty on Linux — see statusline/width.sh + spec 022), the Windows
# port only needs to read that environment variable.

# Get-StatuslineColumns - first non-zero positive integer in:
#   1. $env:CLAUDE_STATUSLINE_COLS (test escape hatch / explicit override)
#   2. $env:COLUMNS                (set by Claude Code before launch)
#   3. literal 80
function Get-StatuslineColumns {
    $override = $env:CLAUDE_STATUSLINE_COLS
    if ($override -match '^\d+$' -and [int]$override -gt 0) {
        return [int]$override
    }

    $columns = $env:COLUMNS
    if ($columns -match '^\d+$' -and [int]$columns -gt 0) {
        return [int]$columns
    }

    80
}
