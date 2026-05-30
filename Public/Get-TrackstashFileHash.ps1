<#
.SYNOPSIS
Computes the SHA256 hash for a media file.

.DESCRIPTION
Uses built-in Get-FileHash with SHA256 to produce deterministic content identity.

.PARAMETER Path
Path to the file to hash.

.OUTPUTS
String SHA256 hex digest.

.EXAMPLE
Get-TrackstashFileHash -Path '/music/track01.flac'
#>
function Get-TrackstashFileHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop
    return $hash.Hash
}
