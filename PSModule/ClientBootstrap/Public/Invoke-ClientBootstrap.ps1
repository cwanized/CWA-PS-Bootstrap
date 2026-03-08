function Invoke-ClientBootstrap {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidAssignmentToAutomaticVariable', '', Justification = 'False positive: client profile terminology is intentional and does not assign to $PROFILE.')]
    [CmdletBinding()]
    param(
        [ValidateSet('Report', 'Enforce')]
        [string]$Mode = 'Report',

        [string]$ConfigurationName,

        [ValidateSet('default', 'sandbox')]
        [string]$Environment = 'default'
    )

    $repositoryRoot = Get-RepositoryRoot
    $logPath = New-BootstrapLogPath -RepositoryRoot $repositoryRoot

    try {
        Write-BootstrapLog -Path $logPath -Message ("Starting ClientBootstrap in mode '{0}'" -f $Mode)

        $clientConfigurationPath = Resolve-ClientConfigurationPath -RepositoryRoot $repositoryRoot -ConfigurationName $ConfigurationName -EnvironmentName $Environment
        Write-BootstrapLog -Path $logPath -Message ("Using client profile {0}" -f $clientConfigurationPath)

        $configuration = Get-MergedConfiguration -RepositoryRoot $repositoryRoot -ClientConfigurationPath $clientConfigurationPath
        $resolvedApplications = Resolve-Applications -Applications $configuration.Applications
        $resolvedPowerShellRepositories = Resolve-PowerShellRepositories -Repositories $configuration.PowerShellRepositories
        $resolvedPowerShellModules = Resolve-PowerShellModules -Modules $configuration.PowerShellModules
        $resolvedOhMyPosh = Resolve-OhMyPoshProfile -Configuration $configuration
        $issues = Test-ConfigurationState -RepositoryRoot $repositoryRoot -Configuration $configuration -ResolvedApplications $resolvedApplications -ResolvedPowerShellRepositories $resolvedPowerShellRepositories -ResolvedPowerShellModules $resolvedPowerShellModules -ResolvedOhMyPosh $resolvedOhMyPosh

        if ($issues.Count -gt 0) {
            foreach ($issue in $issues) {
                Write-BootstrapLog -Path $logPath -Level 'ERROR' -Message $issue
            }

            throw 'Configuration validation failed.'
        }

        Write-BootstrapLog -Path $logPath -Message ("Resolved {0} applications" -f $resolvedApplications.Applications.Count)
        Write-BootstrapLog -Path $logPath -Message ("Resolved {0} PowerShell repositories" -f $resolvedPowerShellRepositories.Repositories.Count)
        Write-BootstrapLog -Path $logPath -Message ("Resolved {0} PowerShell modules" -f $resolvedPowerShellModules.Modules.Count)
        if ($resolvedOhMyPosh.EffectiveProfile) {
            Write-BootstrapLog -Path $logPath -Message ("Resolved Oh My Posh profile {0}" -f $resolvedOhMyPosh.EffectiveProfile)
        }

        switch ($Mode) {
            'Report' {
                Invoke-ReportMode -RepositoryRoot $repositoryRoot -Configuration $configuration -Applications $resolvedApplications.Applications -PowerShellRepositories $resolvedPowerShellRepositories.Repositories -PowerShellModules $resolvedPowerShellModules.Modules -OhMyPoshProfile $resolvedOhMyPosh.EffectiveProfile -LogPath $logPath
            }
            'Enforce' {
                Invoke-EnforceMode -RepositoryRoot $repositoryRoot -Configuration $configuration -Applications $resolvedApplications.Applications -PowerShellRepositories $resolvedPowerShellRepositories.Repositories -PowerShellModules $resolvedPowerShellModules.Modules -OhMyPoshProfile $resolvedOhMyPosh.EffectiveProfile -LogPath $logPath
            }
        }

        Write-BootstrapLog -Path $logPath -Level 'OK' -Message 'ClientBootstrap completed successfully.'

        return [pscustomobject]@{
            LogPath           = $logPath
            ProfilePath       = $clientConfigurationPath
            EffectiveMode     = $Mode
            EffectiveOhMyPosh = $resolvedOhMyPosh.EffectiveProfile
            ApplicationCount  = $resolvedApplications.Applications.Count
            ModuleCount       = $resolvedPowerShellModules.Modules.Count
        }
    }
    catch {
        Write-BootstrapLog -Path $logPath -Level 'ERROR' -Message $_.Exception.Message
        throw
    }
}
