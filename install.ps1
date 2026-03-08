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

function Get-BootstrapSplat {
    [CmdletBinding()]
    param()

    $arguments = @{
        Mode        = $Mode
        Environment = $Environment
    }

    if ($ConfigurationName) {
        $arguments.ConfigurationName = $ConfigurationName
    }

    return $arguments
}

function Get-GitExecutablePath {
    [CmdletBinding()]
    param()

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCommand) {
        return $gitCommand.Source
    }

    $candidatePaths = @(
        'C:\Program Files\Git\cmd\git.exe',
        'C:\Program Files\Git\bin\git.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -Path $candidatePath) {
            return $candidatePath
        }
    }

    return $null
}

function Get-PwshExecutablePath {
    [CmdletBinding()]
    param()

    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCommand) {
        return $pwshCommand.Source
    }

    $candidatePaths = @(
        'C:\Program Files\PowerShell\7\pwsh.exe',
        (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerShell\pwsh.exe')
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -Path $candidatePath) {
            return $candidatePath
        }
    }

    return $null
}

function Install-WingetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,

        [Parameter(Mandatory)]
        [string]$PackageName
    )

    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCommand) {
        throw ("winget is required to install missing bootstrap prerequisite '{0}'." -f $PackageName)
    }

    Write-Host ("Installing {0} via winget" -f $PackageName)
    & $wingetCommand.Source install --id $PackageId --exact --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-String | Write-Host

    if ($LASTEXITCODE -ne 0) {
        throw ("Failed to install {0} via winget." -f $PackageName)
    }
}

function Install-BootstrapTooling {
    [CmdletBinding()]
    param()

    if (-not (Get-GitExecutablePath)) {
        Install-WingetPackage -PackageId 'Git.Git' -PackageName 'Git'
    }

    if (-not (Get-PwshExecutablePath)) {
        Install-WingetPackage -PackageId 'Microsoft.PowerShell' -PackageName 'PowerShell 7'
    }
}

function Test-RepositoryContext {
    [CmdletBinding()]
    param()

    if (-not $PSScriptRoot) {
        return $false
    }

    return (Test-Path -Path (Join-Path $PSScriptRoot 'bootstrap.ps1')) -and
           (Test-Path -Path (Join-Path $PSScriptRoot 'PSModule\ClientBootstrap\ClientBootstrap.psd1'))
}

function Invoke-GitCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [string]$WorkingDirectory
    )

    $gitPath = Get-GitExecutablePath
    if (-not $gitPath) {
        throw 'Git is required for the install loader. Install Git and rerun install.ps1.'
    }

    $output = if ($WorkingDirectory) {
        Push-Location -Path $WorkingDirectory
        try {
            & $gitPath @Arguments 2>&1 | Out-String
        }
        finally {
            Pop-Location
        }
    }
    else {
        & $gitPath @Arguments 2>&1 | Out-String
    }

    if ($LASTEXITCODE -ne 0) {
        throw ("Git command failed: git {0}`n{1}" -f ($Arguments -join ' '), $output.Trim())
    }

    return $output.Trim()
}

function Initialize-RepositoryCheckout {
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

$repositoryRoot = if (Test-RepositoryContext) {
    $PSScriptRoot
}
else {
    Install-BootstrapTooling
    Initialize-RepositoryCheckout
}

$bootstrapScriptPath = Join-Path $repositoryRoot 'bootstrap.ps1'
if (-not (Test-Path -Path $bootstrapScriptPath)) {
    throw ("bootstrap.ps1 not found: {0}" -f $bootstrapScriptPath)
}

$bootstrapSplat = Get-BootstrapSplat
$pwshPath = Get-PwshExecutablePath

if ($PSVersionTable.PSVersion.Major -lt 7) {
    if (-not $pwshPath) {
        throw 'PowerShell 7 is required but was not found after prerequisite installation.'
    }

    & $pwshPath -NoLogo -NoProfile -File $bootstrapScriptPath @bootstrapSplat
    exit $LASTEXITCODE
}

& $bootstrapScriptPath @bootstrapSplat
exit $LASTEXITCODE
