# Managed by chezmoi. Keep host-specific logic in the shared profile module.

$dotfilesProfile = Join-Path $HOME '.config\dotfiles\powershell\profile.ps1'

if (Test-Path -LiteralPath $dotfilesProfile) {
    try {
        . $dotfilesProfile
    } catch {
        Write-Warning "dotfiles PowerShell profile failed: $($_.Exception.Message)"
    }
}
