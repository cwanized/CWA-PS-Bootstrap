function ConvertTo-PowerShellLiteral {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return '$null'
    }

    if ($Value -is [bool]) {
        return $(if ($Value) { '$true' } else { '$false' })
    }

    if ($Value -is [string]) {
        return "'{0}'" -f $Value.Replace("'", "''")
    }

    return "'{0}'" -f ([string]$Value).Replace("'", "''")
}

function Get-PwshExecutablePath {
    [CmdletBinding()]
    param()

    $currentProcess = Get-Process -Id $PID -ErrorAction SilentlyContinue
    if ($currentProcess -and $currentProcess.Path -and ([System.IO.Path]::GetFileNameWithoutExtension($currentProcess.Path) -eq 'pwsh')) {
        return $currentProcess.Path
    }

    $command = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw 'pwsh is required but was not found on the current system.'
}

function Get-WingetDscModule {
    [CmdletBinding()]
    param(
        [string]$LogPath,

        [switch]$InstallIfMissing
    )

    $module = Get-Module -ListAvailable -Name 'Microsoft.WinGet.DSC' | Sort-Object Version -Descending | Select-Object -First 1
    if ($module) {
        return $module
    }

    if (-not $InstallIfMissing) {
        return $null
    }

    if ($LogPath) {
        Write-BootstrapLog -Path $LogPath -Message 'Installing Microsoft.WinGet.DSC for current user.'
    }

    Install-Module Microsoft.WinGet.DSC -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    return Get-Module -ListAvailable -Name 'Microsoft.WinGet.DSC' | Sort-Object Version -Descending | Select-Object -First 1
}

function Invoke-WingetDscPackageResource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Get', 'Set', 'Test')]
        [string]$Method,

        [Parameter(Mandatory)]
        [hashtable]$Application,

        [string]$LogPath,

        [switch]$InstallModuleIfMissing
    )

    $module = Get-WingetDscModule -LogPath $LogPath -InstallIfMissing:$InstallModuleIfMissing
    if (-not $module) {
        throw 'Microsoft.WinGet.DSC is not installed.'
    }

    $pwshPath = Get-PwshExecutablePath
    $temporaryScriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ClientBootstrap-WinGetDsc-{0}.ps1" -f ([guid]::NewGuid().ToString('N')))

    $scriptLines = New-Object System.Collections.Generic.List[string]
    $scriptLines.Add('using module Microsoft.WinGet.DSC')
    $scriptLines.Add('')
    $scriptLines.Add('$ErrorActionPreference = ''Stop''')
    $scriptLines.Add('$package = [WinGetPackage]::new()')
    $scriptLines.Add('$package.Id = {0}' -f (ConvertTo-PowerShellLiteral -Value $Application.Id))

    if ($Application.WingetSource) {
        $scriptLines.Add('$package.Source = {0}' -f (ConvertTo-PowerShellLiteral -Value $Application.WingetSource))
    }

    if ($Application.Version) {
        $scriptLines.Add('$package.Version = {0}' -f (ConvertTo-PowerShellLiteral -Value $Application.Version))
    }

    $useLatest = $false
    if ($Application.ContainsKey('UseLatest')) {
        $useLatest = [bool]$Application.UseLatest
    }

    $installMode = 'Silent'
    if ($Application.InstallMode) {
        $installMode = $Application.InstallMode
    }

    $scriptLines.Add('$package.MatchOption = ''EqualsCaseInsensitive''')
    $scriptLines.Add(('$package.UseLatest = {0}' -f (ConvertTo-PowerShellLiteral -Value $useLatest)))
    $scriptLines.Add(('$package.InstallMode = {0}' -f (ConvertTo-PowerShellLiteral -Value $installMode)))
    $scriptLines.Add('')
    $scriptLines.Add('try {')
    $scriptLines.Add(("    switch ({0}) {{" -f (ConvertTo-PowerShellLiteral -Value $Method)))
    $scriptLines.Add('        ''Get'' {')
    $scriptLines.Add('            $result = $package.Get()')
    $scriptLines.Add('        }')
    $scriptLines.Add('        ''Test'' {')
    $scriptLines.Add('            $result = @{ InDesiredState = $package.Test(); Current = $package.Get() }')
    $scriptLines.Add('        }')
    $scriptLines.Add('        ''Set'' {')
    $scriptLines.Add('            $package.Set()')
    $scriptLines.Add('            $result = @{ InDesiredState = $package.Test(); Current = $package.Get() }')
    $scriptLines.Add('        }')
    $scriptLines.Add('    }')
    $scriptLines.Add('')
    $scriptLines.Add('    $result | ConvertTo-Json -Depth 12 -Compress')
    $scriptLines.Add('}')
    $scriptLines.Add('catch {')
    $scriptLines.Add('    @{ Error = $_.Exception.Message } | ConvertTo-Json -Depth 12 -Compress')
    $scriptLines.Add('    exit 1')
    $scriptLines.Add('}')

    try {
        Set-Content -Path $temporaryScriptPath -Value ($scriptLines -join [Environment]::NewLine) -Force
        $output = & $pwshPath -NoLogo -NoProfile -File $temporaryScriptPath 2>&1 | Out-String

        if ($LASTEXITCODE -ne 0) {
            throw ("winget DSC call failed: {0}" -f $output.Trim())
        }

        $trimmedOutput = $output.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmedOutput)) {
            return $null
        }

        return ($trimmedOutput | ConvertFrom-Json -AsHashtable)
    }
    finally {
        if (Test-Path -Path $temporaryScriptPath) {
            Remove-Item -Path $temporaryScriptPath -Force -ErrorAction SilentlyContinue
        }
    }
}