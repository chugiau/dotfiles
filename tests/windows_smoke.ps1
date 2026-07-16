# windows_smoke.ps1 - structural tests for the native Windows dotfiles path.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Fail = 0
$script:Ok = 0
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Ok {
    param([string]$Message)
    Write-Host "  ok    $Message"
    $script:Ok++
}

function Fail {
    param([string]$Message)
    Write-Error "  fail  $Message" -ErrorAction Continue
    $script:Fail++
}

function Join-RepoPath {
    param([string]$Path)
    Join-Path $RepoRoot $Path
}

function Check-Exists {
    param([string]$Path)
    if (Test-Path -LiteralPath (Join-RepoPath $Path)) {
        Ok "exists: $Path"
    } else {
        Fail "missing: $Path"
    }
}

function Check-Parse {
    param([string]$Path)

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-RepoPath $Path),
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null

    if ($errors.Count -eq 0) {
        Ok "PowerShell parses: $Path"
    } else {
        Fail "PowerShell parse error: $Path"
        foreach ($parseError in $errors) {
            Write-Error "    $($parseError.Message)" -ErrorAction Continue
        }
    }
}

function Check-Contains {
    param(
        [string]$Path,
        [string]$Needle,
        [string]$Message
    )

    $content = Get-Content -LiteralPath (Join-RepoPath $Path) -Raw
    if ($content.Contains($Needle)) {
        Ok $Message
    } else {
        Fail $Message
    }
}

function Check-NotContains {
    param(
        [string]$Path,
        [string]$Needle,
        [string]$Message
    )

    $content = Get-Content -LiteralPath (Join-RepoPath $Path) -Raw
    if ($content.Contains($Needle)) {
        Fail $Message
    } else {
        Ok $Message
    }
}

function Check-Order {
    param(
        [string]$Path,
        [string]$First,
        [string]$Second,
        [string]$Message
    )

    $content = Get-Content -LiteralPath (Join-RepoPath $Path) -Raw
    $firstIndex = $content.IndexOf($First)
    $secondIndex = $content.IndexOf($Second)
    if ($firstIndex -ge 0 -and $secondIndex -ge 0 -and $firstIndex -lt $secondIndex) {
        Ok $Message
    } else {
        Fail $Message
    }
}

Write-Host 'Windows smoke tests: chezmoi + mise dotfiles'
Write-Host ''

Write-Host '[structure]'
foreach ($path in @(
        'bootstrap.ps1',
        'bin/dotfiles.ps1',
        'home/.chezmoiignore',
        'home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1',
        'home/dot_config/dotfiles/powershell/profile.ps1',
        'home/run_once_before_05-windows-packages.ps1.tmpl',
        'home/run_onchange_after_11-mise-windows.ps1.tmpl',
        'home/run_once_after_12-codex-windows.ps1.tmpl',
        'home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl',
        'home/dot_claude/statusline-command.ps1',
        'home/dot_claude/statusline-windows/Core.ps1',
        'home/dot_claude/statusline-windows/Data.ps1',
        'home/dot_claude/statusline-windows/Width.ps1',
        'home/dot_claude/statusline-windows/Items.ps1',
        'home/dot_claude/statusline-windows/Layout.ps1'
    )) {
    Check-Exists $path
}
Write-Host ''

Write-Host '[PowerShell parse]'
foreach ($path in @(
        'bootstrap.ps1',
        'bin/dotfiles.ps1',
        'home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1',
        'home/dot_config/dotfiles/powershell/profile.ps1',
        'home/run_once_before_05-windows-packages.ps1.tmpl',
        'home/run_onchange_after_11-mise-windows.ps1.tmpl',
        'home/run_once_after_12-codex-windows.ps1.tmpl',
        'home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl',
        'home/dot_claude/statusline-command.ps1',
        'home/dot_claude/statusline-windows/Core.ps1',
        'home/dot_claude/statusline-windows/Data.ps1',
        'home/dot_claude/statusline-windows/Width.ps1',
        'home/dot_claude/statusline-windows/Items.ps1',
        'home/dot_claude/statusline-windows/Layout.ps1'
    )) {
    if (Test-Path -LiteralPath (Join-RepoPath $path)) {
        Check-Parse $path
    }
}
Write-Host ''

Write-Host '[Windows bootstrap]'
if (Test-Path -LiteralPath (Join-RepoPath 'bootstrap.ps1')) {
    Check-Contains 'bootstrap.ps1' 'winget install --id $Id' 'bootstrap.ps1 installs packages through winget'
    Check-Contains 'bootstrap.ps1' 'Git.Git' 'bootstrap.ps1 declares the Git winget package'
    Check-Contains 'bootstrap.ps1' 'twpayne.chezmoi' 'bootstrap.ps1 declares the chezmoi winget package'
    Check-Contains 'bootstrap.ps1' 'jdx.mise' 'bootstrap.ps1 declares the mise winget package'
    Check-Contains 'bootstrap.ps1' 'chezmoi apply' 'bootstrap.ps1 runs chezmoi apply'
    Check-Contains 'home/run_once_before_05-windows-packages.ps1.tmpl' 'direnv.direnv' 'Windows package setup installs native direnv'
}
Write-Host ''

Write-Host '[mise manifest]'
if (Test-Path -LiteralPath (Join-RepoPath 'home/dot_config/mise/config.toml')) {
    Check-Contains 'home/dot_config/mise/config.toml' '"aqua:eza-community/eza" = "latest"' 'mise manifest installs eza through aqua'
    Check-NotContains 'home/dot_config/mise/config.toml' 'eza     = "latest"' 'mise manifest does not use bare eza shorthand'
    Check-Contains 'home/dot_config/mise/config.toml' 'os = ["linux", "macos"]' 'mise manifest excludes codex from native Windows'
    Check-NotContains 'home/dot_config/mise/config.toml' 'codex   = "latest"' 'mise manifest does not use bare codex shorthand'
}
Write-Host ''

Write-Host '[codex install]'
if (Test-Path -LiteralPath (Join-RepoPath 'home/run_once_after_12-codex-windows.ps1.tmpl')) {
    Check-Contains 'home/run_once_after_12-codex-windows.ps1.tmpl' 'IsWindows' 'Codex Windows installer guards on $IsWindows'
    Check-Contains 'home/run_once_after_12-codex-windows.ps1.tmpl' 'Get-Command codex' 'Codex Windows installer skips an existing install'
    Check-Contains 'home/run_once_after_12-codex-windows.ps1.tmpl' "irm https://chatgpt.com/codex/install.ps1 | iex" 'Codex Windows installer uses the official irm | iex one-liner'
    Check-Contains 'home/run_once_after_12-codex-windows.ps1.tmpl' 'ExecutionPolicy ByPass' 'Codex Windows installer bypasses execution policy'
    Check-NotContains 'home/run_once_after_12-codex-windows.ps1.tmpl' 'npm install' 'Codex Windows installer does not shell out to npm install'
}
if (Test-Path -LiteralPath (Join-RepoPath 'bin/dotfiles.ps1')) {
    Check-Contains 'bin/dotfiles.ps1' "irm https://chatgpt.com/codex/install.ps1 | iex" 'dotfiles.ps1 update refreshes Codex via the official irm | iex one-liner'
}
Write-Host ''

Write-Host '[PowerShell profile]'
if (Test-Path -LiteralPath (Join-RepoPath 'home/dot_config/dotfiles/powershell/profile.ps1')) {
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' 'mise activate pwsh' 'PowerShell profile activates mise'
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' '.local\share\mise\shims' 'PowerShell profile exposes user-scope mise shims'
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' 'LOCALAPPDATA' 'PowerShell profile exposes native Windows mise shims'
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' '$env:HOME = $HOME' 'PowerShell profile exports $env:HOME for POSIX-style tools'
    Check-Order 'home/dot_config/dotfiles/powershell/profile.ps1' '$env:HOME = $HOME' 'hook pwsh' 'PowerShell profile sets $env:HOME before hooking direnv'
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' 'hook pwsh' 'PowerShell profile hooks direnv'
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' 'Get-Command direnv.exe' 'PowerShell profile prefers native direnv.exe'
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' 'IsNullOrWhiteSpace' 'PowerShell profile skips empty direnv hook output'
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' 'oh-my-posh init pwsh' 'PowerShell profile guards oh-my-posh'
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' 'slimfat.omp.json' 'PowerShell profile defaults to the slimfat oh-my-posh theme'
}
Write-Host ''

Write-Host '[chezmoi platform split]'
if (Test-Path -LiteralPath (Join-RepoPath 'home/.chezmoiignore')) {
    Check-Contains 'home/.chezmoiignore' '05-windows-packages.ps1' 'non-Windows ignores Windows package script by target name'
    Check-Contains 'home/.chezmoiignore' '11-mise-windows.ps1' 'non-Windows ignores Windows mise script by target name'
    Check-Contains 'home/.chezmoiignore' '12-codex-windows.ps1' 'non-Windows ignores Windows codex script by target name'
    Check-Contains 'home/.chezmoiignore' '13-claude-statusline-windows.ps1' 'non-Windows ignores Windows statusline wiring script by target name'
    Check-Contains 'home/.chezmoiignore' '.claude/statusline-windows/' 'non-Windows ignores Windows statusline module directory by target path'
    Check-Contains 'home/.chezmoiignore' '.claude/statusline-command.ps1' 'non-Windows ignores Windows statusline entrypoint by target path'
    Check-Contains 'home/.chezmoiignore' '10-system-packages.sh' 'Windows ignores Unix package script by target name'
    Check-Contains 'home/.chezmoiignore' '63-codex-security.sh' 'Windows ignores Unix agent script by target name'
    Check-Contains 'home/.chezmoiignore' '.claude/statusline/' 'Windows ignores Unix statusline module directory by target path'
    Check-Contains 'home/.chezmoiignore' '.claude/statusline-command.sh' 'Windows ignores Unix statusline entrypoint by target path'
    Check-Contains 'home/.chezmoiignore' '.config/dotfiles/powershell/' 'non-Windows ignores PowerShell module by target path'
    Check-Contains 'home/.chezmoiignore' '.config/dotfiles/modules/' 'Windows ignores zsh modules by target path'
}
Write-Host ''

Write-Host '[claude statusline wiring]'
if (Test-Path -LiteralPath (Join-RepoPath 'home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl')) {
    Check-Contains 'home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl' 'IsWindows' 'Statusline wiring script guards on $IsWindows'
    Check-Contains 'home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl' 'statusLine' 'Statusline wiring script sets the statusLine settings.json key'
    Check-Contains 'home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl' 'ConvertFrom-Json' 'Statusline wiring script parses settings.json without jq'
    Check-Contains 'home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl' 'ConvertTo-Json' 'Statusline wiring script serializes settings.json without jq'
    Check-Contains 'home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl' "-replace '\\', '/'" 'Statusline wiring script forward-slashes the command path (Git Bash backslash quoting)'
    Check-Contains 'home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl' 'pwsh -NoProfile -NoLogo -File' 'Statusline wiring script invokes pwsh -NoProfile -NoLogo -File'
    Check-NotContains 'home/run_onchange_after_13-claude-statusline-windows.ps1.tmpl' 'jq -' 'Statusline wiring script does not shell out to jq'
}
Write-Host ''

Write-Host '[claude statusline modules]'
if (Test-Path -LiteralPath (Join-RepoPath 'home/dot_claude/statusline-command.ps1')) {
    foreach ($mod in @('Core', 'Data', 'Width', 'Items', 'Layout')) {
        Check-Contains 'home/dot_claude/statusline-command.ps1' "statusline-windows/$mod.ps1" "entrypoint dot-sources statusline-windows/$mod.ps1"
    }
    Check-Contains 'home/dot_claude/statusline-command.ps1' '[System.Text.UTF8Encoding]' 'entrypoint builds a UTF-8 (no BOM) encoding for stdout'
    Check-Contains 'home/dot_claude/statusline-command.ps1' '[Console]::SetOut(' "entrypoint rewraps stdout as UTF-8 so Claude Code's redirected-pipe capture does not mangle emoji/box-drawing glyphs"
    Check-Contains 'home/dot_claude/statusline-command.ps1' '[Console]::OpenStandardInput()' 'entrypoint reads stdin as UTF-8 so non-ASCII JSON values (e.g. CJK folder names) are not mangled'
}
if (Test-Path -LiteralPath (Join-RepoPath 'home/dot_claude/statusline-windows/Width.ps1')) {
    Check-Contains 'home/dot_claude/statusline-windows/Width.ps1' 'CLAUDE_STATUSLINE_COLS' 'Get-StatuslineColumns honours the CLAUDE_STATUSLINE_COLS escape hatch'
    Check-Contains 'home/dot_claude/statusline-windows/Width.ps1' 'env:COLUMNS' 'Get-StatuslineColumns reads $env:COLUMNS'
    Check-Contains 'home/dot_claude/statusline-windows/Width.ps1' '80' 'Get-StatuslineColumns falls back to literal 80'
}
if (Test-Path -LiteralPath (Join-RepoPath 'home/dot_claude/statusline-windows/Layout.ps1')) {
    Check-Contains 'home/dot_claude/statusline-windows/Layout.ps1' 'Invoke-LayoutPack' 'Invoke-LayoutPack is defined in Layout.ps1'
    Check-Contains 'home/dot_claude/statusline-windows/Layout.ps1' 'Invoke-LayoutRender' 'Invoke-LayoutRender is defined in Layout.ps1'
    Check-Contains 'home/dot_claude/statusline-windows/Layout.ps1' '5' 'Layout.ps1 references a 5-line cap'
}
Write-Host ''

Write-Host '[claude statusline behaviour]'
$statuslineEntrypoint = Join-RepoPath 'home/dot_claude/statusline-command.ps1'
if ((Test-Path -LiteralPath $statuslineEntrypoint) -and (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    $fixture = @'
{
  "model": {"id":"claude-opus-4-7","display_name":"Opus"},
  "workspace": {"current_dir":"C:/tmp","project_dir":"C:/tmp"},
  "cwd": "C:/tmp",
  "session_id": "spec041-test",
  "transcript_path": "",
  "version": "2.1.90",
  "cost": {"total_cost_usd":0.123,"total_duration_ms":60000,"total_api_duration_ms":15000},
  "context_window": {
    "total_input_tokens": 12000,
    "total_output_tokens": 3000,
    "used_percentage": 25,
    "current_usage": {
      "input_tokens": 1000,
      "output_tokens": 200,
      "cache_creation_input_tokens": 500,
      "cache_read_input_tokens": 4000
    }
  },
  "rate_limits": {
    "five_hour": {"used_percentage":42,"resets_at":9999999999},
    "seven_day": {"used_percentage":13,"resets_at":9999999999}
  }
}
'@

    function Invoke-StatuslineFixture {
        param(
            [string]$Cols,
            [string]$FixtureText = $fixture
        )

        Remove-Item Env:\COLUMNS -ErrorAction SilentlyContinue
        $env:CLAUDE_STATUSLINE_COLS = $Cols
        try {
            $result = $FixtureText | & pwsh -NoProfile -File $statuslineEntrypoint 2>$null
        } finally {
            Remove-Item Env:\CLAUDE_STATUSLINE_COLS -ErrorAction SilentlyContinue
        }
        , @($result | Where-Object { $_ -ne $null -and $_ -ne '' })
    }

    $out300 = Invoke-StatuslineFixture -Cols '300'
    $joined300 = $out300 -join "`n"
    if ($out300.Count -eq 1 -and $joined300.Contains('Opus') -and $joined300.Contains('Context')) {
        Ok "width=300 renders 1 line containing model + Context"
    } else {
        Fail "width=300 produced $($out300.Count) line(s); expected 1 with Opus+Context"
    }

    $out80 = Invoke-StatuslineFixture -Cols '80'
    $joined80 = $out80 -join "`n"
    if ($out80.Count -ge 2 -and $out80.Count -le 5 -and $joined80.Contains('Opus') -and $joined80.Contains('Context')) {
        Ok "width=80 renders $($out80.Count) line(s) containing model + Context"
    } else {
        Fail "width=80 produced $($out80.Count) line(s); expected 2-5 with Opus+Context"
    }

    $out40 = Invoke-StatuslineFixture -Cols '40'
    $joined40 = $out40 -join "`n"
    if ($out40.Count -ge 1 -and $out40.Count -le 5 -and $joined40.Contains('Opus')) {
        Ok "width=40 renders $($out40.Count) line(s) within max-5 cap, model present"
    } else {
        Fail "width=40 produced $($out40.Count) line(s); expected 1-5 with Opus"
    }
    if ($joined40.Contains('Weekly')) {
        Fail "width=40 still shows P2 'Weekly' bar (drop logic broken)"
    } else {
        Ok "width=40 drops the P2 Weekly bar"
    }

    # Capturing a native command's output through PowerShell's own pipeline
    # (`$result = ... | & pwsh ...`, as Invoke-StatuslineFixture does above)
    # decodes the child's stdout bytes using this *outer* session's
    # [Console]::OutputEncoding (the OEM/ANSI code page) before the string
    # ever reaches $result — the very problem the entrypoint's stdout/stdin
    # fixes exist to avoid, just relocated to the test harness. Claude Code
    # never goes through that: it's a Node process reading the child's raw
    # bytes directly. Start-Process with file-redirected stdin/stdout
    # sidesteps PowerShell's pipeline decoding entirely (OS-level file
    # handles, no intermediate string conversion), matching how Claude Code
    # actually captures this script's output.
    $cjkFixture = $fixture -replace '"current_dir":"C:/tmp","project_dir":"C:/tmp"', '"current_dir":"C:/tmp/測試專案","project_dir":"C:/tmp/測試專案"'
    $cjkInFile = [System.IO.Path]::GetTempFileName()
    $cjkOutFile = [System.IO.Path]::GetTempFileName()
    $cjkErrFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($cjkInFile, $cjkFixture, [System.Text.UTF8Encoding]::new($false))
        Remove-Item Env:\COLUMNS -ErrorAction SilentlyContinue
        $env:CLAUDE_STATUSLINE_COLS = '300'
        try {
            Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $statuslineEntrypoint) `
                -RedirectStandardInput $cjkInFile -RedirectStandardOutput $cjkOutFile -RedirectStandardError $cjkErrFile `
                -NoNewWindow -Wait
        } finally {
            Remove-Item Env:\CLAUDE_STATUSLINE_COLS -ErrorAction SilentlyContinue
        }
        $cjkOutText = [System.IO.File]::ReadAllText($cjkOutFile, [System.Text.UTF8Encoding]::new($false))
    } finally {
        Remove-Item -LiteralPath $cjkInFile, $cjkOutFile, $cjkErrFile -ErrorAction SilentlyContinue
    }
    if ($cjkOutText.Contains('測試專案')) {
        Ok "stdin decodes non-ASCII (CJK) JSON string values correctly"
    } else {
        Fail "stdin mangled the CJK folder name; got: $cjkOutText"
    }
} else {
    Write-Host '  skip  statusline-command.ps1 missing or pwsh unavailable'
}
Write-Host ''

Write-Host "Result: $script:Ok ok, $script:Fail failed"
if ($script:Fail -ne 0) {
    exit 1
}
