function Invoke-ClientBootstrap {
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

        $profilePath = Resolve-ClientProfilePath -RepositoryRoot $repositoryRoot -ProfileName $ConfigurationName -EnvironmentName $Environment
        Write-BootstrapLog -Path $logPath -Message ("Using client profile {0}" -f $profilePath)

        $configuration = Get-MergedConfiguration -RepositoryRoot $repositoryRoot -ProfilePath $profilePath
        $resolvedApplications = Resolve-Applications -Applications $configuration.Applications
        $resolvedOhMyPosh = Resolve-OhMyPoshProfile -Configuration $configuration
        $issues = Test-ConfigurationState -RepositoryRoot $repositoryRoot -Configuration $configuration -ResolvedApplications $resolvedApplications -ResolvedOhMyPosh $resolvedOhMyPosh

        if ($issues.Count -gt 0) {
            foreach ($issue in $issues) {
                Write-BootstrapLog -Path $logPath -Level 'ERROR' -Message $issue
            }

            throw 'Configuration validation failed.'
        }

        Write-BootstrapLog -Path $logPath -Message ("Resolved {0} applications" -f $resolvedApplications.Applications.Count)
        if ($resolvedOhMyPosh.EffectiveProfile) {
            Write-BootstrapLog -Path $logPath -Message ("Resolved Oh My Posh profile {0}" -f $resolvedOhMyPosh.EffectiveProfile)
        }

        switch ($Mode) {
            'Report' {
                Invoke-ReportMode -RepositoryRoot $repositoryRoot -Configuration $configuration -Applications $resolvedApplications.Applications -OhMyPoshProfile $resolvedOhMyPosh.EffectiveProfile -LogPath $logPath
            }
            'Enforce' {
                Invoke-EnforceMode -RepositoryRoot $repositoryRoot -Configuration $configuration -Applications $resolvedApplications.Applications -OhMyPoshProfile $resolvedOhMyPosh.EffectiveProfile -LogPath $logPath
            }
        }

        Write-BootstrapLog -Path $logPath -Level 'OK' -Message 'ClientBootstrap completed successfully.'

        return [pscustomobject]@{
            LogPath           = $logPath
            ProfilePath       = $profilePath
            EffectiveMode     = $Mode
            EffectiveOhMyPosh = $resolvedOhMyPosh.EffectiveProfile
            ApplicationCount  = $resolvedApplications.Applications.Count
        }
    }
    catch {
        Write-BootstrapLog -Path $logPath -Level 'ERROR' -Message $_.Exception.Message
        throw
    }
}
