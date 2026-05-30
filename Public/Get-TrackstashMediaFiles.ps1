<#
.SYNOPSIS
Enumerates supported media files from one or more roots.

.DESCRIPTION
Returns file path, size, last modified UTC timestamp, and normalized format
for supported audio extensions.

.PARAMETER Root
One or more root directories to scan.

.PARAMETER Recurse
When set, scans subdirectories recursively.

.OUTPUTS
PSCustomObject with Path, SizeBytes, LastModifiedUtc, and Format.

.EXAMPLE
Get-TrackstashMediaFiles -Root '/music' -Recurse
#>
function Get-TrackstashMediaFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Root,

        [Parameter()]
        [switch]$Recurse
    )

    $supportedExtensions = @('.flac', '.mp3', '.wav', '.aiff', '.m4a', '.ogg')

    foreach ($rootPath in $Root) {
        $fullRoot = [System.IO.Path]::GetFullPath($rootPath)
        if (-not (Test-Path -LiteralPath $fullRoot)) {
            Write-TrackstashLog -Level Warning -Message "Root path does not exist: $fullRoot"
            continue
        }

        Get-ChildItem -LiteralPath $fullRoot -File -Recurse:$Recurse -ErrorAction SilentlyContinue |
            Where-Object { $supportedExtensions -contains $_.Extension.ToLowerInvariant() } |
            ForEach-Object {
                [pscustomobject]@{
                    Path            = $_.FullName
                    SizeBytes       = $_.Length
                    LastModifiedUtc = $_.LastWriteTimeUtc
                    Format          = $_.Extension.TrimStart('.').ToLowerInvariant()
                }
            }
    }
}
