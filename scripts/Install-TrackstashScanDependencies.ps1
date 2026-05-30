#requires -Version 7.4

<#
.SYNOPSIS
Bootstraps first-run dependencies for trackstash-scan.

.DESCRIPTION
Installs psMusicTagger and PsAcoustId from PSGallery and downloads
Microsoft.Data.Sqlite.Core plus required SQLitePCLRaw packages from NuGet.
Copies managed and native SQLite assets into the local Dependencies folder used
by the module.

.PARAMETER Scope
Install scope for psMusicTagger. CurrentUser by default.

.PARAMETER SqliteVersion
NuGet package version for Microsoft.Data.Sqlite.Core.

.PARAMETER SQLitePCLRawVersion
NuGet package version for SQLitePCLRaw dependencies.

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
    [string]$SqliteVersion = '9.0.16',

    [Parameter()]
    [string]$SQLitePCLRawVersion = '2.1.10',

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
$sqlitePclTargetRoot = Join-Path $depsRoot 'SQLitePCLRaw'
$sqliteNativeTargetRoot = Join-Path $sqlitePclTargetRoot 'native'

function Get-RuntimeNativeRelativePath {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant()

    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
        return "runtimes/osx-$arch/native/libe_sqlite3.dylib"
    }
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
        return "runtimes/linux-$arch/native/libe_sqlite3.so"
    }
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        return "runtimes/win-$arch/native/e_sqlite3.dll"
    }

    throw 'Unsupported OS platform for SQLite native runtime selection.'
}

function Download-And-ExtractNuGetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$DestinationRoot
    )

    $nupkgPath = Join-Path $DestinationRoot ("$PackageId.$Version.nupkg")
    $extractPath = Join-Path $DestinationRoot ("$PackageId.$Version")
    $packageIdLower = $PackageId.ToLowerInvariant()
    $versionLower = $Version.ToLowerInvariant()
    $nugetUrl = "https://www.nuget.org/api/v2/package/$packageIdLower/$versionLower"

    if (Get-Command -Name curl -ErrorAction SilentlyContinue) {
        & curl -fsSL "$nugetUrl" -o "$nupkgPath"
        if ($LASTEXITCODE -ne 0) {
            throw "curl failed to download package from $nugetUrl"
        }
    }
    else {
        Invoke-WebRequest -Uri $nugetUrl -OutFile $nupkgPath
    }
    Expand-Archive -LiteralPath $nupkgPath -DestinationPath $extractPath -Force
    return $extractPath
}

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

Write-Step 'Installing PsAcoustId from PSGallery.'
$installAcoustIdParams = @{
    Name         = 'PsAcoustId'
    Repository   = 'PSGallery'
    Scope        = $Scope
    Force        = [bool]$Force
    AllowClobber = $true
    ErrorAction  = 'Stop'
}
Install-Module @installAcoustIdParams

Write-Step "Downloading Microsoft.Data.Sqlite.Core v$SqliteVersion from NuGet."
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("trackstash-scan-bootstrap-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $sqliteCoreExtractPath = Download-And-ExtractNuGetPackage -PackageId 'Microsoft.Data.Sqlite.Core' -Version $SqliteVersion -DestinationRoot $tempRoot
    $sqlitePclCoreExtractPath = Download-And-ExtractNuGetPackage -PackageId 'SQLitePCLRaw.core' -Version $SQLitePCLRawVersion -DestinationRoot $tempRoot
    $sqlitePclProviderExtractPath = Download-And-ExtractNuGetPackage -PackageId 'SQLitePCLRaw.provider.dynamic_cdecl' -Version $SQLitePCLRawVersion -DestinationRoot $tempRoot
    $sqlitePclProviderESqlite3ExtractPath = Download-And-ExtractNuGetPackage -PackageId 'SQLitePCLRaw.provider.e_sqlite3' -Version $SQLitePCLRawVersion -DestinationRoot $tempRoot
    $sqlitePclBundleExtractPath = Download-And-ExtractNuGetPackage -PackageId 'SQLitePCLRaw.bundle_e_sqlite3' -Version $SQLitePCLRawVersion -DestinationRoot $tempRoot
    $sqlitePclNativeExtractPath = Download-And-ExtractNuGetPackage -PackageId 'SQLitePCLRaw.lib.e_sqlite3' -Version $SQLitePCLRawVersion -DestinationRoot $tempRoot

    $candidateDlls = @(
        Join-Path $sqliteCoreExtractPath 'lib/net8.0/Microsoft.Data.Sqlite.dll'
        Join-Path $sqliteCoreExtractPath 'lib/net6.0/Microsoft.Data.Sqlite.dll'
        Join-Path $sqliteCoreExtractPath 'lib/netstandard2.0/Microsoft.Data.Sqlite.dll'
    )

    $resolvedDll = $candidateDlls | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $resolvedDll) {
        throw 'Could not find Microsoft.Data.Sqlite.dll in Microsoft.Data.Sqlite.Core package.'
    }

    New-Item -ItemType Directory -Path $sqliteTargetRoot -Force | Out-Null
    Copy-Item -LiteralPath $resolvedDll -Destination $sqliteTargetDll -Force

    New-Item -ItemType Directory -Path $sqlitePclTargetRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $sqliteNativeTargetRoot -Force | Out-Null

    $managedCopies = @(
        @{
            SourceCandidates = @(
                (Join-Path $sqlitePclCoreExtractPath 'lib/netstandard2.0/SQLitePCLRaw.core.dll')
            )
            DestinationName = 'SQLitePCLRaw.core.dll'
        },
        @{
            SourceCandidates = @(
                (Join-Path $sqlitePclProviderExtractPath 'lib/netstandard2.0/SQLitePCLRaw.provider.dynamic_cdecl.dll')
            )
            DestinationName = 'SQLitePCLRaw.provider.dynamic_cdecl.dll'
        },
        @{
            SourceCandidates = @(
                (Join-Path $sqlitePclProviderESqlite3ExtractPath 'lib/netstandard2.0/SQLitePCLRaw.provider.e_sqlite3.dll')
            )
            DestinationName = 'SQLitePCLRaw.provider.e_sqlite3.dll'
        },
        @{
            SourceCandidates = @(
                (Join-Path $sqlitePclBundleExtractPath 'lib/net6.0/SQLitePCLRaw.batteries_v2.dll'),
                (Join-Path $sqlitePclBundleExtractPath 'lib/netstandard2.0/SQLitePCLRaw.batteries_v2.dll')
            )
            DestinationName = 'SQLitePCLRaw.batteries_v2.dll'
        }
    )

    foreach ($copy in $managedCopies) {
        $resolvedSource = $copy.SourceCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if (-not $resolvedSource) {
            throw "Could not find managed dependency: $($copy.DestinationName)"
        }

        Copy-Item -LiteralPath $resolvedSource -Destination (Join-Path $sqlitePclTargetRoot $copy.DestinationName) -Force
    }

    $nativePreferred = Join-Path $sqlitePclNativeExtractPath (Get-RuntimeNativeRelativePath)
    $nativeSource = if (Test-Path -LiteralPath $nativePreferred) {
        $nativePreferred
    }
    else {
        Get-ChildItem -Path (Join-Path $sqlitePclNativeExtractPath 'runtimes') -Recurse -File |
            Where-Object { $_.Name -in @('e_sqlite3.dll', 'libe_sqlite3.so', 'libe_sqlite3.dylib') } |
            Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $nativeSource) {
        throw 'Could not find native e_sqlite3 runtime library in SQLitePCLRaw.lib.e_sqlite3 package.'
    }

    $nativeFileName = Split-Path -Path $nativeSource -Leaf
    Copy-Item -LiteralPath $nativeSource -Destination (Join-Path $sqliteNativeTargetRoot $nativeFileName) -Force
    Copy-Item -LiteralPath $nativeSource -Destination (Join-Path $sqlitePclTargetRoot $nativeFileName) -Force

    Write-Step "Installed Microsoft.Data.Sqlite assembly to $sqliteTargetDll"
    Write-Step "Installed SQLitePCLRaw managed dependencies to $sqlitePclTargetRoot"
    Write-Step "Installed SQLite native runtime to $sqliteNativeTargetRoot"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Step 'Bootstrap complete. You can now run the scanner.'
