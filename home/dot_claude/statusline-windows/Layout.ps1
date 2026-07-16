# statusline-windows/Layout.ps1 - pack item records into at most 5 output
# lines, dropping low-priority items (P3 -> P2 -> P1, rightmost first within
# a tier) while respecting the canonical order. The renderer ANSI-aware
# truncates the trailing line when even the survivors overflow. Mirrors
# home/dot_claude/statusline/layout.sh, operating on the $Items list of
# [PSCustomObject]@{Id;Text;Width;Priority} records instead of encoded
# strings.

$LayoutMaxLines = 5
$LayoutSep = ' | '
$LayoutSepW = 3

# Invoke-LayoutPackOnce <items> <width> - greedy left-to-right wrap
# respecting `width`. Returns @{ Lines = [...]; Widths = [...] }.
function Invoke-LayoutPackOnce {
    param(
        [System.Collections.Generic.List[object]]$Items,
        [int]$Width
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $widths = [System.Collections.Generic.List[int]]::new()
    $curText = ''
    $curW = 0

    foreach ($item in $Items) {
        $text = $item.Text
        $w = $item.Width

        if ([string]::IsNullOrEmpty($curText)) {
            $curText = $text
            $curW = $w
        } elseif (($curW + $LayoutSepW + $w) -gt ($Width - 1)) {
            $lines.Add($curText)
            $widths.Add($curW)
            $curText = $text
            $curW = $w
        } else {
            $curText = "$curText$LayoutSep$text"
            $curW = $curW + $LayoutSepW + $w
        }
    }

    if ($curText) {
        $lines.Add($curText)
        $widths.Add($curW)
    }

    [PSCustomObject]@{ Lines = $lines; Widths = $widths }
}

# Invoke-LayoutPack <width>
#
# Reads script-scope $Items, writes $script:PlanLines (joined-text per line,
# with ANSI) and $script:PlanWidths (visible-column count per line). Drops
# happen in two phases:
#   1. Preemptive: any non-P0 item whose own visible width exceeds
#      (width-1) is dropped - it can't fit on a single line and would be
#      truncated by the renderer anyway.
#   2. Reactive: while the greedy wrap exceeds max lines, drop the
#      rightmost item with the highest priority number. P0 items are never
#      dropped; if they alone overflow, the renderer truncates.
function Invoke-LayoutPack {
    param([int]$Width)

    $lineCap = $Width - 1
    $work = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $script:Items) {
        if ($item.Priority -eq 0 -or $item.Width -le $lineCap) {
            $work.Add($item)
        }
    }

    while ($true) {
        $packed = Invoke-LayoutPackOnce -Items $work -Width $Width
        if ($packed.Lines.Count -le $LayoutMaxLines) {
            $script:PlanLines = $packed.Lines
            $script:PlanWidths = $packed.Widths
            return
        }

        $dropIdx = -1
        $dropPrio = 0
        for ($i = $work.Count - 1; $i -ge 0; $i--) {
            if ($work[$i].Priority -gt $dropPrio) {
                $dropPrio = $work[$i].Priority
                $dropIdx = $i
            }
        }

        if ($dropIdx -lt 0 -or $dropPrio -le 0) {
            # Only P0 items remain; accept the overflow and let the
            # renderer truncate the trailing line.
            $script:PlanLines = $packed.Lines
            $script:PlanWidths = $packed.Widths
            return
        }

        $work.RemoveAt($dropIdx)
    }
}

# Invoke-LayoutRender <width>
#
# Print $script:PlanLines, one per line, ANSI-aware truncating any line
# whose pre-computed visible width exceeds `width`.
function Invoke-LayoutRender {
    param([int]$Width)

    for ($i = 0; $i -lt $script:PlanLines.Count; $i++) {
        $line = $script:PlanLines[$i]
        $visW = $script:PlanWidths[$i]
        if ($visW -le $Width) {
            Write-Output $line
        } else {
            $stripped = Remove-AnsiCodes $line
            $cut = [math]::Max(0, $Width - 1)
            $cut = [math]::Min($cut, $stripped.Length)
            Write-Output ($stripped.Substring(0, $cut) + '…')
        }
    }
}
