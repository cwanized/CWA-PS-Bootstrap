[CmdletBinding()]
param(
    [ValidateSet('Report', 'Enforce')]
    [string]$Mode = 'Report',

    [string]$ConfigurationName,

    [ValidateSet('default', 'sandbox')]
    [string]$Environment = 'default'
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCommand) {
        & $pwshCommand.Source -NoLogo -NoProfile -File $PSCommandPath -Mode $Mode -ConfigurationName $ConfigurationName -Environment $Environment
        exit $LASTEXITCODE
    }

    throw 'PowerShell 7 is required. Install pwsh and rerun bootstrap.ps1.'
}

$moduleManifest = Join-Path $PSScriptRoot 'PSModule\ClientBootstrap\ClientBootstrap.psd1'
Import-Module $moduleManifest -Force

Invoke-ClientBootstrap -Mode $Mode -ConfigurationName $ConfigurationName -Environment $Environment
