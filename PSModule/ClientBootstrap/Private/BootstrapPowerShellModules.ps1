function Get-BootstrapPowerShellModuleDefinitions {
    [CmdletBinding()]
    param()

    return @(
        @{
            Name       = 'Microsoft.WinGet.DSC'
            Repository = 'PSGallery'
        }
    )
}

function Test-PowerShellRepositoryConfigured {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Repository
    )

    $existingRepository = Get-PSRepository -Name $Repository.Name -ErrorAction SilentlyContinue
    if (-not $existingRepository) {
        return $false
    }

    if ($Repository.InstallationPolicy) {
        return $existingRepository.InstallationPolicy.ToString() -eq $Repository.InstallationPolicy
    }

    return $true
}

function Set-PowerShellRepositoryConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Repository,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $policy = if ($Repository.InstallationPolicy) { $Repository.InstallationPolicy } else { 'Trusted' }
    $existingRepository = Get-PSRepository -Name $Repository.Name -ErrorAction SilentlyContinue

    if ($existingRepository) {
        $setSplat = @{
            Name               = $Repository.Name
            InstallationPolicy = $policy
            ErrorAction        = 'Stop'
        }

        if ($Repository.SourceLocation) {
            $setSplat.SourceLocation = $Repository.SourceLocation
        }

        if ($Repository.PublishLocation) {
            $setSplat.PublishLocation = $Repository.PublishLocation
        }

        if ($Repository.ScriptSourceLocation) {
            $setSplat.ScriptSourceLocation = $Repository.ScriptSourceLocation
        }

        if ($Repository.ScriptPublishLocation) {
            $setSplat.ScriptPublishLocation = $Repository.ScriptPublishLocation
        }

        Set-PSRepository @setSplat
        Write-BootstrapLog -Path $LogPath -Message ("Configured PowerShell repository {0} as {1}" -f $Repository.Name, $policy)
        return
    }

    if (-not $Repository.SourceLocation) {
        throw ("PowerShell repository '{0}' is not known locally and requires SourceLocation for registration." -f $Repository.Name)
    }

    $registerSplat = @{
        Name               = $Repository.Name
        SourceLocation     = $Repository.SourceLocation
        InstallationPolicy = $policy
        ErrorAction        = 'Stop'
    }

    if ($Repository.PublishLocation) {
        $registerSplat.PublishLocation = $Repository.PublishLocation
    }

    if ($Repository.ScriptSourceLocation) {
        $registerSplat.ScriptSourceLocation = $Repository.ScriptSourceLocation
    }

    if ($Repository.ScriptPublishLocation) {
        $registerSplat.ScriptPublishLocation = $Repository.ScriptPublishLocation
    }

    Register-PSRepository @registerSplat
    Write-BootstrapLog -Path $LogPath -Message ("Registered PowerShell repository {0} as {1}" -f $Repository.Name, $policy)
}

function Test-PowerShellModuleInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Module
    )

    $installedModule = Get-InstalledModule -Name $Module.Name -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $installedModule) {
        $installedModule = Get-Module -ListAvailable -Name $Module.Name | Sort-Object Version -Descending | Select-Object -First 1
    }

    if (-not $installedModule) {
        return $false
    }

    if ($Module.RequiredVersion) {
        return ([version]$installedModule.Version) -eq ([version]$Module.RequiredVersion)
    }

    if ($Module.MinimumVersion) {
        return ([version]$installedModule.Version) -ge ([version]$Module.MinimumVersion)
    }

    return $true
}

function Install-PowerShellModuleDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Module,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $installSplat = @{
        Name        = $Module.Name
        Scope       = 'CurrentUser'
        Force       = $true
        AllowClobber = $true
        ErrorAction = 'Stop'
    }

    if ($Module.Repository) {
        $installSplat.Repository = $Module.Repository
    }

    if ($Module.RequiredVersion) {
        $installSplat.RequiredVersion = $Module.RequiredVersion
    }
    elseif ($Module.MinimumVersion) {
        $installSplat.MinimumVersion = $Module.MinimumVersion
    }

    Install-Module @installSplat
    Write-BootstrapLog -Path $LogPath -Message ("Installed PowerShell module {0}" -f $Module.Name)
}

function Install-BootstrapPowerShellModules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogPath
    )

    foreach ($module in @(Get-BootstrapPowerShellModuleDefinitions)) {
        if (Test-PowerShellModuleInstalled -Module $module) {
            Write-BootstrapLog -Path $LogPath -Level 'OK' -Message ("Bootstrap PowerShell module already installed: {0}" -f $module.Name)
            continue
        }

        if ($module.Repository) {
            $repositoryDefinition = @{
                Name               = $module.Repository
                InstallationPolicy = 'Trusted'
            }

            if (Get-PSRepository -Name $module.Repository -ErrorAction SilentlyContinue) {
                Set-PowerShellRepositoryConfiguration -Repository $repositoryDefinition -LogPath $LogPath
            }
        }

        Install-PowerShellModuleDefinition -Module $module -LogPath $LogPath
    }
}

function Invoke-ReportPowerShellRepositories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Repositories,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    foreach ($repository in $Repositories) {
        $configured = Test-PowerShellRepositoryConfigured -Repository $repository
        $status = if ($configured) { 'OK' } else { 'MISSING' }
        Write-BootstrapLog -Path $LogPath -Level ($(if ($configured) { 'OK' } else { 'WARN' })) -Message ("{0} PowerShell repository {1}" -f $status, $repository.Name)
    }
}

function Invoke-ReportPowerShellModules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Modules,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    foreach ($module in $Modules) {
        $installed = Test-PowerShellModuleInstalled -Module $module
        $status = if ($installed) { 'OK' } else { 'MISSING' }
        Write-BootstrapLog -Path $LogPath -Level ($(if ($installed) { 'OK' } else { 'WARN' })) -Message ("{0} PowerShell module {1}" -f $status, $module.Name)
    }
}

function Invoke-EnforcePowerShellRepositories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Repositories,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    foreach ($repository in $Repositories) {
        if (Test-PowerShellRepositoryConfigured -Repository $repository) {
            Write-BootstrapLog -Path $LogPath -Level 'OK' -Message ("PowerShell repository already configured: {0}" -f $repository.Name)
            continue
        }

        Set-PowerShellRepositoryConfiguration -Repository $repository -LogPath $LogPath
    }
}

function Invoke-EnforcePowerShellModules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Modules,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    foreach ($module in $Modules) {
        if (Test-PowerShellModuleInstalled -Module $module) {
            Write-BootstrapLog -Path $LogPath -Level 'OK' -Message ("PowerShell module already installed: {0}" -f $module.Name)
            continue
        }

        Install-PowerShellModuleDefinition -Module $module -LogPath $LogPath
    }
}
