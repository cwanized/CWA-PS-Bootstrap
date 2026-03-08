function Set-RepoRootLocation {
    param([string]$Path = (Join-Path $HOME '_Repos'))

    if (Test-Path -Path $Path) {
        Set-Location -Path $Path
    }
}
