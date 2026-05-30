#requires -Version 7.4

<#
.SYNOPSIS
Bootstraps first-run dependencies for trackstash-scan.

.DESCRIPTION
Installs psMusicTagger from PSGallery and downloads Microsoft.Data.Sqlite from NuGet,
then copies the Sqlite assembly into the local Dependencies folder used by the module.

.PARAMETER Scope
Install scope for psMusicTagger. CurrentUser by default.

.PARAMETER SqliteVersion
NuGet package version for Microsoft.Data.Sqlite.

.PARAMETER Force
Forces reinstall/overwrite behavior where possible.

.EXAMPLE
pwsh ./scripts/Install-TrackstashScanDependencies.ps1
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',

    [Parameter()]
    [string]$SqliteVersion = '8.0.7',

    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[trackstash-scan bootstrap] $Message"
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$depsRoot = Join-Path $repoRoot 'Dependencies'
$sqliteTargetRoot = Join-Path $depsRoot 'Microsoft.Data.Sqlite'
$sqliteTargetDll = Join-Path $sqliteTargetRoot 'Microsoft.Data.Sqlite.dll'

Write-Step 'Checking PowerShellGet/PackageManagement prerequisites.'
if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force | Out-Null
}

if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Default
}

Write-Step 'Installing psMusicTagger from PSGallery.'
$installModuleParams = @{
    Name         = 'psMusicTagger'
    Repository   = 'PSGallery'
    Scope        = $Scope
    Force        = [bool]$Force
    AllowClobber = $true
    ErrorAction  = 'Stop'
}
Install-Module @installModuleParams

Write-Step "Downloading Microsoft.Data.Sqlite v$SqliteVersion from NuGet."
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("trackstash-scan-bootstrap-" + [guid]::NewGuid().ToString('N'))
$nupkgPath = Join-Path $tempRoot 'Microsoft.Data.Sqlite.nupkg'
$extractPath = Join-Path $tempRoot 'extract'

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

try {
    $nugetUrl = "https://www.nuget.org/api/v2/package/Microsoft.Data.Sqlite/$SqliteVersion"
    Invoke-WebRequest -Uri $nugetUrl -OutFile $nupkgPath

    Expand-Archive -LiteralPath $nupkgPath -DestinationPath $extractPath -Force

    $candidateDlls = @(
        Join-Path $extractPath 'lib/net8.0/Microsoft.Data.Sqlite.dll'
        Join-Path $extractPath 'lib/net7.0/Microsoft.Data.Sqlite.dll'
        Join-Path $extractPath 'lib/net6.0/Microsoft.Data.Sqlite.dll'
        Join-Path $extractPath 'lib/netstandard2.0/Microsoft.Data.Sqlite.dll'
    )

    $resolvedDll = $candidateDlls | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $resolvedDll) {
        throw 'Could not find Microsoft.Data.Sqlite.dll in downloaded package.'
    }

    New-Item -ItemType Directory -Path $sqliteTargetRoot -Force | Out-Null
    Copy-Item -LiteralPath $resolvedDll -Destination $sqliteTargetDll -Force

    Write-Step "Installed Microsoft.Data.Sqlite assembly to $sqliteTargetDll"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Step 'Bootstrap complete. You can now run the scanner.'
