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
        'home/run_onchange_after_11-mise-windows.ps1.tmpl'
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
        'home/run_onchange_after_11-mise-windows.ps1.tmpl'
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
}
Write-Host ''

Write-Host '[mise manifest]'
if (Test-Path -LiteralPath (Join-RepoPath 'home/dot_config/mise/config.toml')) {
    Check-Contains 'home/dot_config/mise/config.toml' '"aqua:eza-community/eza" = "latest"' 'mise manifest installs eza through aqua'
    Check-NotContains 'home/dot_config/mise/config.toml' 'eza     = "latest"' 'mise manifest does not use bare eza shorthand'
}
Write-Host ''

Write-Host '[PowerShell profile]'
if (Test-Path -LiteralPath (Join-RepoPath 'home/dot_config/dotfiles/powershell/profile.ps1')) {
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' 'mise activate pwsh' 'PowerShell profile activates mise'
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' 'direnv hook pwsh' 'PowerShell profile hooks direnv'
    Check-Contains 'home/dot_config/dotfiles/powershell/profile.ps1' 'oh-my-posh init pwsh' 'PowerShell profile guards oh-my-posh'
}
Write-Host ''

Write-Host '[chezmoi platform split]'
if (Test-Path -LiteralPath (Join-RepoPath 'home/.chezmoiignore')) {
    Check-Contains 'home/.chezmoiignore' '05-windows-packages.ps1' 'non-Windows ignores Windows package script by target name'
    Check-Contains 'home/.chezmoiignore' '11-mise-windows.ps1' 'non-Windows ignores Windows mise script by target name'
    Check-Contains 'home/.chezmoiignore' '10-system-packages.sh' 'Windows ignores Unix package script by target name'
    Check-Contains 'home/.chezmoiignore' '63-codex-security.sh' 'Windows ignores Unix agent script by target name'
    Check-Contains 'home/.chezmoiignore' '.config/dotfiles/powershell/' 'non-Windows ignores PowerShell module by target path'
    Check-Contains 'home/.chezmoiignore' '.config/dotfiles/modules/' 'Windows ignores zsh modules by target path'
}
Write-Host ''

Write-Host "Result: $script:Ok ok, $script:Fail failed"
if ($script:Fail -ne 0) {
    exit 1
}
