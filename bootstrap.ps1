[CmdletBinding()]
param(
    [ValidateSet('Report', 'Enforce')]
    [string]$Mode = 'Report',

    [string]$ConfigurationName,

    [ValidateSet('default', 'sandbox')]
    [string]$Environment = 'default'
)

$script:BootstrapRepositoryUrl = 'https://github.com/cwanized/CWA-PS-Bootstrap.git'
$script:BootstrapCheckoutPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'CWA-PS-Bootstrap\repo'
$script:BootstrapScriptDefinition = $MyInvocation.MyCommand.Definition

function Get-BootstrapInvocationArguments {
    [CmdletBinding()]
    param()

    $arguments = @(
        '-Mode', $Mode,
        '-Environment', $Environment
    )

    if ($ConfigurationName) {
        $arguments += @('-ConfigurationName', $ConfigurationName)
    }

    return $arguments
}

function Test-LocalBootstrapContext {
    [CmdletBinding()]
    param()

    if (-not $PSScriptRoot) {
        return $false
    }

    $moduleManifest = Join-Path $PSScriptRoot 'PSModule\ClientBootstrap\ClientBootstrap.psd1'
    return (Test-Path -Path $moduleManifest)
}

function Invoke-InPwsh {
    [CmdletBinding()]
    param()

    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwshCommand) {
        throw 'PowerShell 7 is required. Install pwsh and rerun bootstrap.ps1.'
    }

    $invokeArguments = Get-BootstrapInvocationArguments

    if ($PSCommandPath -and (Test-Path -Path $PSCommandPath)) {
        & $pwshCommand.Source -NoLogo -NoProfile -File $PSCommandPath @invokeArguments
        exit $LASTEXITCODE
    }

    if ([string]::IsNullOrWhiteSpace($script:BootstrapScriptDefinition)) {
        throw 'Unable to relaunch the bootstrap script in pwsh because the current script content is unavailable.'
    }

    $temporaryScriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ("CWA-PS-Bootstrap-Loader-{0}.ps1" -f ([guid]::NewGuid().ToString('N')))

    try {
        Set-Content -Path $temporaryScriptPath -Value $script:BootstrapScriptDefinition -Force
        & $pwshCommand.Source -NoLogo -NoProfile -File $temporaryScriptPath @invokeArguments
        exit $LASTEXITCODE
    }
    finally {
        if (Test-Path -Path $temporaryScriptPath) {
            Remove-Item -Path $temporaryScriptPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-GitCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [string]$WorkingDirectory
    )

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) {
        throw 'Git is required for bootstrap repository checkout. Install Git and rerun bootstrap.ps1.'
    }

    $output = if ($WorkingDirectory) {
        Push-Location -Path $WorkingDirectory
        try {
            & $gitCommand.Source @Arguments 2>&1 | Out-String
        }
        finally {
            Pop-Location
        }
    }
    else {
        & $gitCommand.Source @Arguments 2>&1 | Out-String
    }

    if ($LASTEXITCODE -ne 0) {
        throw ("Git command failed: git {0}`n{1}" -f ($Arguments -join ' '), $output.Trim())
    }

    return $output.Trim()
}

function Initialize-BootstrapRepositoryCheckout {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'False positive: stale analyzer message still references the previous function name Ensure-BootstrapRepositoryCheckout.')]
    [CmdletBinding()]
    param()

    $checkoutParent = Split-Path -Path $script:BootstrapCheckoutPath -Parent
    if (-not (Test-Path -Path $checkoutParent)) {
        $null = New-Item -Path $checkoutParent -ItemType Directory -Force
    }

    $gitFolder = Join-Path $script:BootstrapCheckoutPath '.git'
    if (Test-Path -Path $gitFolder) {
        Write-Host ("Updating bootstrap repository in {0}" -f $script:BootstrapCheckoutPath)
        $null = Invoke-GitCommand -WorkingDirectory $script:BootstrapCheckoutPath -Arguments @('remote', 'set-url', 'origin', $script:BootstrapRepositoryUrl)
        $null = Invoke-GitCommand -WorkingDirectory $script:BootstrapCheckoutPath -Arguments @('pull', '--ff-only')
        return $script:BootstrapCheckoutPath
    }

    if (Test-Path -Path $script:BootstrapCheckoutPath) {
        throw ("Bootstrap checkout path already exists but is not a Git repository: {0}" -f $script:BootstrapCheckoutPath)
    }

    Write-Host ("Cloning bootstrap repository from {0}" -f $script:BootstrapRepositoryUrl)
    $null = Invoke-GitCommand -Arguments @('clone', $script:BootstrapRepositoryUrl, $script:BootstrapCheckoutPath)
    return $script:BootstrapCheckoutPath
}

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

function Invoke-RepositoryBootstrap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    Install-BootstrapPowerShellDependencies

    $moduleManifest = Join-Path $RepositoryRoot 'PSModule\ClientBootstrap\ClientBootstrap.psd1'
    if (-not (Test-Path -Path $moduleManifest)) {
        throw ("ClientBootstrap module manifest not found: {0}" -f $moduleManifest)
    }

    Import-Module $moduleManifest -Force
    Invoke-ClientBootstrap -Mode $Mode -ConfigurationName $ConfigurationName -Environment $Environment
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Invoke-InPwsh
}

$repositoryRoot = if (Test-LocalBootstrapContext) {
    $PSScriptRoot
}
else {
    Initialize-BootstrapRepositoryCheckout
}

Invoke-RepositoryBootstrap -RepositoryRoot $repositoryRoot
