function Get-RepositoryRoot {
    [CmdletBinding()]
    param()

    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "JSON file not found: $Path"
    }

    return (Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable)
}

function Resolve-ConfigPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    return Join-Path $RepositoryRoot ($RelativePath -replace '/', '\\')
}

function Resolve-ClientProfilePath {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [string]$ProfileName,

        [string]$EnvironmentName
    )

    $clientsRoot = Join-Path $RepositoryRoot 'Config\Clients'

    if ($ProfileName) {
        $explicitPath = Join-Path $clientsRoot ("$ProfileName.json")
        if (-not (Test-Path -Path $explicitPath)) {
            throw "Client profile not found: $explicitPath"
        }

        return $explicitPath
    }

    if ($EnvironmentName -eq 'sandbox') {
        $sandboxPath = Join-Path $clientsRoot 'sandbox-debug.json'
        if (Test-Path -Path $sandboxPath) {
            return $sandboxPath
        }
    }

    $hostnamePath = Join-Path $clientsRoot ("$env:COMPUTERNAME.json")
    if (Test-Path -Path $hostnamePath) {
        return $hostnamePath
    }

    $defaultPath = Join-Path $clientsRoot 'developer-default.json'
    if (-not (Test-Path -Path $defaultPath)) {
        throw "Fallback client profile not found: $defaultPath"
    }

    return $defaultPath
}

function Get-MergedConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $profile = Read-JsonFile -Path $ProfilePath
    $categoriesRoot = Join-Path $RepositoryRoot 'Config\Categories'

    $configuration = [ordered]@{
        ProfilePath                = $ProfilePath
        ProfileName                = [System.IO.Path]::GetFileNameWithoutExtension($ProfilePath)
        Categories                 = @($profile.Categories)
        Applications               = New-Object System.Collections.Generic.List[hashtable]
        Folders                    = New-Object System.Collections.Generic.List[string]
        Configurations             = New-Object System.Collections.Generic.List[hashtable]
        PowerShellProfileFragments = New-Object System.Collections.Generic.List[string]
        CategoryOhMyPoshProfiles   = New-Object System.Collections.Generic.List[string]
        ClientOhMyPoshProfile      = $profile.OhMyPoshProfile
    }

    foreach ($categoryName in @($profile.Categories)) {
        $categoryPath = Join-Path $categoriesRoot ("$categoryName.json")
        $category = Read-JsonFile -Path $categoryPath

        foreach ($application in @($category.Applications)) {
            $configuration.Applications.Add(([hashtable]$application))
        }

        foreach ($folder in @($category.Folders)) {
            $configuration.Folders.Add($folder)
        }

        foreach ($item in @($category.Configurations)) {
            $configuration.Configurations.Add(([hashtable]$item))
        }

        foreach ($fragment in @($category.PowerShellProfileFragments)) {
            $configuration.PowerShellProfileFragments.Add($fragment)
        }

        if ($category.OhMyPoshProfile) {
            $configuration.CategoryOhMyPoshProfiles.Add($category.OhMyPoshProfile)
        }
    }

    return $configuration
}

function Get-SourcePriority {
    param(
        [Parameter(Mandatory)]
        [string]$Source
    )

    switch ($Source.ToLowerInvariant()) {
        'winget' { return 1 }
        'choco'  { return 2 }
        'msi'    { return 3 }
        'exe'    { return 4 }
        default  { return 99 }
    }
}

function Resolve-Applications {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Applications
    )

    $resolved = New-Object System.Collections.Generic.List[hashtable]
    $conflicts = New-Object System.Collections.Generic.List[string]
    $grouped = @{}

    foreach ($application in $Applications) {
        if (-not $application.Name) {
            $conflicts.Add('Application entry is missing required property "Name".')
            continue
        }

        $key = $application.Name.ToLowerInvariant()
        if (-not $grouped.ContainsKey($key)) {
            $grouped[$key] = New-Object System.Collections.Generic.List[hashtable]
        }

        $grouped[$key].Add(([hashtable]$application))
    }

    foreach ($entry in $grouped.GetEnumerator()) {
        $orderedEntries = @($entry.Value | Sort-Object { Get-SourcePriority -Source $_.Source })
        if ($orderedEntries.Count -eq 0) {
            continue
        }

        $highestPriority = Get-SourcePriority -Source $orderedEntries[0].Source
        $samePriorityEntries = @($orderedEntries | Where-Object { (Get-SourcePriority -Source $_.Source) -eq $highestPriority })

        if ($samePriorityEntries.Count -gt 1) {
            $serialized = @($samePriorityEntries | ForEach-Object { $_ | ConvertTo-Json -Depth 8 -Compress } | Select-Object -Unique)
            if ($serialized.Count -gt 1) {
                $conflicts.Add("Application '$($orderedEntries[0].Name)' has multiple conflicting definitions with source '$($orderedEntries[0].Source)'.")
                continue
            }
        }

        $resolved.Add($orderedEntries[0])
    }

    return [ordered]@{
        Applications = $resolved
        Conflicts    = $conflicts
    }
}

function Resolve-OhMyPoshProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )

    $profiles = @($Configuration.CategoryOhMyPoshProfiles | Where-Object { $_ } | Select-Object -Unique)
    $clientProfile = $Configuration.ClientOhMyPoshProfile

    if ($clientProfile) {
        return [ordered]@{
            EffectiveProfile = $clientProfile
            Conflict         = $null
        }
    }

    if ($profiles.Count -le 1) {
        return [ordered]@{
            EffectiveProfile = $profiles[0]
            Conflict         = $null
        }
    }

    return [ordered]@{
        EffectiveProfile = $null
        Conflict         = 'Multiple categories define different OhMyPoshProfile values. Resolve this explicitly in the client profile.'
    }
}

function Test-ConfigurationState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [hashtable]$ResolvedApplications,

        [Parameter(Mandatory)]
        [hashtable]$ResolvedOhMyPosh
    )

    $issues = New-Object System.Collections.Generic.List[string]

    foreach ($application in @($ResolvedApplications.Applications)) {
        switch ($application.Source) {
            'winget' {
                if (-not $application.Id) {
                    $issues.Add("Application '$($application.Name)' requires property 'Id' for source 'winget'.")
                }
            }
            'choco' {
                if (-not $application.Id) {
                    $issues.Add("Application '$($application.Name)' requires property 'Id' for source 'choco'.")
                }
            }
            'msi' {
                if (-not $application.Url -and -not $application.Path) {
                    $issues.Add("Application '$($application.Name)' requires either 'Url' or 'Path' for source 'msi'.")
                }
            }
            'exe' {
                if (-not $application.Url -and -not $application.Path) {
                    $issues.Add("Application '$($application.Name)' requires either 'Url' or 'Path' for source 'exe'.")
                }
            }
            default {
                $issues.Add("Application '$($application.Name)' uses unsupported source '$($application.Source)'.")
            }
        }
    }

    foreach ($fragment in @($Configuration.PowerShellProfileFragments | Select-Object -Unique)) {
        $fragmentPath = Resolve-ConfigPath -RepositoryRoot $RepositoryRoot -RelativePath $fragment
        if (-not (Test-Path -Path $fragmentPath)) {
            $issues.Add("PowerShell fragment not found: $fragment")
        }
    }

    if ($ResolvedOhMyPosh.EffectiveProfile) {
        $ompPath = Join-Path $RepositoryRoot ("Config\Applications\OhMyPosh\Profiles\$($ResolvedOhMyPosh.EffectiveProfile).omp.json")
        if (-not (Test-Path -Path $ompPath)) {
            $issues.Add("Oh My Posh profile not found: $($ResolvedOhMyPosh.EffectiveProfile)")
        }
    }

    if ($ResolvedOhMyPosh.Conflict) {
        $issues.Add($ResolvedOhMyPosh.Conflict)
    }

    foreach ($conflict in @($ResolvedApplications.Conflicts)) {
        $issues.Add($conflict)
    }

    return $issues
}
