function New-BootstrapLogPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $logDirectory = Join-Path $RepositoryRoot 'Logs'
    if (-not (Test-Path -Path $logDirectory)) {
        $null = New-Item -Path $logDirectory -ItemType Directory -Force
    }

    return Join-Path $logDirectory ('{0:yyyy-MM-dd-HHmmss}-bootstrap.log' -f (Get-Date))
}

function Write-BootstrapLog {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')]
        [string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $Path -Value $line

    switch ($Level) {
        'ERROR' { Write-Error $Message }
        'WARN' { Write-Warning $Message }
        Default { Write-Host $Message }
    }
}
