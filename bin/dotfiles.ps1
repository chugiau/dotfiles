# dotfiles.ps1 - native Windows wrapper around chezmoi + mise.

[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Command,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Write-Ok {
    param([string]$Message)
    Write-Host "  ok    $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  fail  $Message" -ForegroundColor Red
}

function Write-Skip {
    param([string]$Message)
    Write-Host "  skip  $Message" -ForegroundColor Yellow
}

function Has-Command {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @()
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath exited with code $LASTEXITCODE"
    }
}

function Show-Usage {
    @'
Usage: dotfiles.ps1 <command> [args]

Commands:
  install          Apply chezmoi and install every mise-managed tool
  update           Update chezmoi source and mise tools
  link             Re-apply chezmoi
  check            Dry-run (chezmoi diff)
  doctor           Verify expected Windows tools and runtime paths
  test             Run Windows smoke tests and optional POSIX tests
  secrets-init     Generate the age key and wire chezmoi.toml for encryption
  edit             Open the dotfiles repo in $EDITOR

Examples:
  .\bin\dotfiles.ps1 install
  .\bin\dotfiles.ps1 doctor
  .\bin\dotfiles.ps1 test
'@
}

function Invoke-Install {
    if (-not (Has-Command chezmoi)) {
        throw 'chezmoi not installed - run bootstrap.ps1 first'
    }

    chezmoi apply

    if (Has-Command mise) {
        mise install
        mise doctor
        if ($LASTEXITCODE -ne 0) {
            Write-Fail 'mise doctor reported issues - review output above'
        }
    } else {
        Write-Fail 'mise not installed - run bootstrap.ps1 first'
    }
}

function Invoke-Update {
    if (Has-Command chezmoi) {
        chezmoi update
    }
    if (Has-Command mise) {
        mise upgrade
    }
    if (Has-Command nvim) {
        nvim --headless '+Lazy! update' +qa
    }
}

function Invoke-Link {
    Invoke-External -FilePath chezmoi -ArgumentList @('apply')
}

function Invoke-Check {
    Invoke-External -FilePath chezmoi -ArgumentList (@('diff') + $Args)
}

function Invoke-Edit {
    $editor = $env:EDITOR
    if (-not $editor) {
        if (Has-Command nvim) {
            $editor = 'nvim'
        } elseif (Has-Command code) {
            $editor = 'code'
        } else {
            $editor = 'notepad'
        }
    }

    & $editor $RepoRoot
}

function Invoke-Test {
    $testFail = 0
    $powerShell = if (Has-Command pwsh) { 'pwsh' } else { 'powershell' }

    Write-Host '[windows smoke]'
    try {
        Invoke-External -FilePath $powerShell -ArgumentList @('-NoProfile', '-File', (Join-Path $RepoRoot 'tests/windows_smoke.ps1'))
        Write-Ok 'Windows smoke tests passed'
    } catch {
        Write-Fail "Windows smoke tests failed: $_"
        $testFail = 1
    }
    Write-Host ''

    Write-Host '[POSIX smoke]'
    if (Has-Command sh) {
        try {
            Invoke-External -FilePath sh -ArgumentList @((Join-Path $RepoRoot 'tests\test_smoke.sh'))
            Write-Ok 'POSIX smoke tests passed'
        } catch {
            Write-Fail "POSIX smoke tests failed: $_"
            $testFail = 1
        }
    } else {
        Write-Skip 'sh not found - skipping POSIX smoke tests'
    }
    Write-Host ''

    if (Has-Command bats) {
        Write-Host '[bats]'
        Push-Location $RepoRoot
        try {
            Invoke-External -FilePath bats -ArgumentList @('tests/bats')
            Write-Ok 'Bats suite passed'
        } catch {
            Write-Fail "Bats suite failed: $_"
            $testFail = 1
        } finally {
            Pop-Location
        }
    } else {
        Write-Skip 'bats not found - skipping Bats suite'
    }

    if ($testFail -ne 0) {
        exit 1
    }
}

function Invoke-SecretsInit {
    if (-not (Has-Command age-keygen)) {
        throw "age-keygen not found - install age first, then re-run"
    }

    $configDir = Join-Path $HOME '.config\chezmoi'
    $configFile = Join-Path $configDir 'chezmoi.toml'
    $keyFile = Join-Path $configDir 'key.txt'

    New-Item -ItemType Directory -Force -Path $configDir | Out-Null

    if (Test-Path -LiteralPath $keyFile) {
        Write-Ok "age key already present: $keyFile"
    } else {
        Write-Ok "generating age key -> $keyFile"
        age-keygen -o $keyFile 2>$null
    }

    $recipient = Select-String -LiteralPath $keyFile -Pattern '^# public key:\s+(.+)$' |
        Select-Object -First 1 |
        ForEach-Object { $_.Matches[0].Groups[1].Value }

    if (-not $recipient) {
        throw "could not read public key from $keyFile"
    }
    if (-not (Test-Path -LiteralPath $configFile)) {
        throw "chezmoi config missing: $configFile (run bootstrap.ps1 first)"
    }

    $config = Get-Content -LiteralPath $configFile -Raw
    if ($config -match 'encryption\s*=\s*"age"') {
        Write-Ok 'chezmoi.toml already configured for age encryption'
    } else {
        $identityPath = $keyFile -replace '\\', '/'
        Add-Content -LiteralPath $configFile -Value @"

# Added by 'dotfiles secrets-init' - chezmoi file encryption via age.
encryption = "age"
[age]
    identity = "$identityPath"
    recipient = "$recipient"
"@
        Write-Ok "appended [age] block to $configFile"
    }
}

function Invoke-Doctor {
    $ok = 0
    $fail = 0

    Write-Host 'Checking installed tools...'
    Write-Host ''
    foreach ($tool in @('git', 'chezmoi', 'mise', 'pwsh', 'nvim', 'jq', 'bat', 'eza', 'lazygit', 'glow', 'node', 'bun', 'gh', 'glab', 'codex', 'direnv')) {
        $cmd = Get-Command $tool -ErrorAction SilentlyContinue
        if ($cmd) {
            Write-Ok "$tool ($($cmd.Source))"
            $ok++
        } else {
            Write-Fail "$tool NOT FOUND"
            $fail++
        }
    }

    Write-Host ''
    foreach ($path in @(
            (Join-Path $HOME '.config\dotfiles'),
            (Join-Path $HOME '.config\mise\config.toml'),
            (Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
        )) {
        if (Test-Path -LiteralPath $path) {
            Write-Ok "present: $path"
            $ok++
        } else {
            Write-Fail "missing: $path"
            $fail++
        }
    }

    Write-Host ''
    Write-Host "Result: $ok ok, $fail failed"
    if ($fail -ne 0) {
        exit 1
    }
}

switch ($Command) {
    'install' { Invoke-Install }
    'update' { Invoke-Update }
    'link' { Invoke-Link }
    'check' { Invoke-Check }
    'doctor' { Invoke-Doctor }
    'test' { Invoke-Test }
    'secrets-init' { Invoke-SecretsInit }
    'edit' { Invoke-Edit }
    { $_ -in @('-h', '--help', 'help', $null, '') } { Show-Usage }
    default {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}
