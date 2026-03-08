[CmdletBinding()]
param(
    [ValidateSet('Report', 'Enforce')]
    [string]$Mode = 'Report',

    [string]$ConfigurationName,

    [ValidateSet('default', 'sandbox')]
    [string]$Environment = 'default'
)

function Install-BootstrapPowerShellDependencies {
    [CmdletBinding()]
    param()

    $requiredModules = @(
        @{
            Name       = 'Microsoft.WinGet.DSC'
            Repository = 'PSGallery'
        }
    )

    foreach ($module in $requiredModules) {
        $installedModule = Get-Module -ListAvailable -Name $module.Name | Sort-Object Version -Descending | Select-Object -First 1
        if ($installedModule) {
            Write-Host ("Bootstrap PowerShell module already installed: {0}" -f $module.Name)
            continue
        }

        if ($module.Repository -and (Get-PSRepository -Name $module.Repository -ErrorAction SilentlyContinue)) {
            Set-PSRepository -Name $module.Repository -InstallationPolicy Trusted -ErrorAction Stop
        }

        Write-Host ("Installing bootstrap PowerShell module {0}" -f $module.Name)
        Install-Module -Name $module.Name -Repository $module.Repository -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCommand) {
        & $pwshCommand.Source -NoLogo -NoProfile -File $PSCommandPath -Mode $Mode -ConfigurationName $ConfigurationName -Environment $Environment
        exit $LASTEXITCODE
    }

    throw 'PowerShell 7 is required. Install pwsh and rerun bootstrap.ps1.'
}

Install-BootstrapPowerShellDependencies

$moduleManifest = Join-Path $PSScriptRoot 'PSModule\ClientBootstrap\ClientBootstrap.psd1'
Import-Module $moduleManifest -Force

Invoke-ClientBootstrap -Mode $Mode -ConfigurationName $ConfigurationName -Environment $Environment
