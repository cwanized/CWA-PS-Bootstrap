$publicScripts = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue | Sort-Object Name
$privateScripts = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue | Sort-Object Name

foreach ($script in @($privateScripts) + @($publicScripts)) {
    . $script.FullName
}

Export-ModuleMember -Function 'Invoke-ClientBootstrap'
