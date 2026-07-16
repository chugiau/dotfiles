# Shared PowerShell profile for native Windows shells.

function Add-PathEntry {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return
    }

    $separator = [IO.Path]::PathSeparator
    $entries = $env:Path -split [regex]::Escape([string]$separator)
    if ($entries -notcontains $Path) {
        $env:Path = "$Path$separator$env:Path"
    }
}

function Test-InteractiveConsole {
    $Host.Name -notmatch 'ServerRemoteHost|Default Host'
}

$env:HOME = $HOME
$env:DOTFILES_REPO = Join-Path $HOME '.dotfiles'
$env:DOTFILES = Join-Path $HOME '.config\dotfiles'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:EDITOR = if (Get-Command nvim -ErrorAction SilentlyContinue) { 'nvim' } else { 'notepad' }
$env:VISUAL = $env:EDITOR

Add-PathEntry (Join-Path $HOME 'bin')
Add-PathEntry (Join-Path $HOME '.local\bin')
Add-PathEntry (Join-Path $HOME '.local\share\mise\shims')
if ($env:LOCALAPPDATA) {
    Add-PathEntry (Join-Path $env:LOCALAPPDATA 'mise\shims')
}

if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
    if (Test-InteractiveConsole) {
        try {
            Set-PSReadLineOption -PredictionSource History
            Set-PSReadLineOption -PredictionViewStyle ListView
            Set-PSReadLineOption -EditMode Windows
        } catch {
            # Older hosts and redirected consoles can reject these options.
        }
    }
}

$completionFiles = @(
    (Join-Path $HOME '.config\dotnet\dotnet-completions.ps1'),
    (Join-Path $HOME '.config\winget\winget-completions.ps1')
)
foreach ($completionFile in $completionFiles) {
    if (Test-Path -LiteralPath $completionFile) {
        Import-Module $completionFile -ErrorAction SilentlyContinue
    }
}

$ompCommand = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($ompCommand) {
    try {
        $ompConfig = @(
            (Join-Path $HOME '.config\oh-my-posh\theme.omp.json'),
            (Join-Path $HOME '.config\oh-my-posh\default.omp.json')
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

        if (-not $ompConfig -and $env:POSH_THEMES_PATH) {
            $slimfatTheme = Join-Path $env:POSH_THEMES_PATH 'slimfat.omp.json'
            if (Test-Path -LiteralPath $slimfatTheme) {
                $ompConfig = $slimfatTheme
            }
        }

        if ($ompConfig) {
            oh-my-posh init pwsh --config $ompConfig | Invoke-Expression
        } else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    } catch {
        # Ignore broken WindowsApps aliases or partially removed installs.
    }
}

if (Get-Command mise -ErrorAction SilentlyContinue) {
    try {
        (& mise activate pwsh) | Out-String | Invoke-Expression
    } catch {
        Write-Warning "mise activation failed: $($_.Exception.Message)"
    }
}

$direnvCommand = Get-Command direnv.exe -ErrorAction SilentlyContinue
if ($direnvCommand) {
    try {
        $direnvHook = (& $direnvCommand.Source hook pwsh) | Out-String
        if (-not [string]::IsNullOrWhiteSpace($direnvHook)) {
            Invoke-Expression $direnvHook
        }
    } catch {
        Write-Warning "direnv hook failed: $($_.Exception.Message)"
    }
}

if (Get-Command eza -ErrorAction SilentlyContinue) {
    Set-Alias ls eza -Scope Global
    Set-Alias ll eza -Scope Global
} else {
    Set-Alias ll Get-ChildItem -Scope Global
}
if (Get-Command git -ErrorAction SilentlyContinue) {
    Set-Alias g git -Scope Global
}
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Set-Alias vim nvim -Scope Global
}
