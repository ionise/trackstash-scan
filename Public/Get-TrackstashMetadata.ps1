<#
.SYNOPSIS
Extracts and normalizes audio metadata using psMusicTagger.

.DESCRIPTION
Calls Get-MusicMetadata and maps tag fields to a consistent schema expected by
trackstash-scan. Missing values are normalized to null where applicable.

.PARAMETER Path
Path to the media file.

.OUTPUTS
PSCustomObject normalized metadata fields.

.EXAMPLE
Get-TrackstashMetadata -Path '/music/track01.mp3'
#>
function Get-TrackstashMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $raw = Get-MusicMetadata -Path $Path -ErrorAction Stop

    $artworkHash = $null
    if ($null -ne $raw.PSObject.Properties['ArtworkHash']) {
        $artworkHash = $raw.ArtworkHash
    }

    return [pscustomobject]@{
        Artist      = $raw.Artist
        Title       = $raw.Title
        Album       = $raw.Album
        Label       = $raw.Label
        Release     = $raw.Release
        TrackNumber = if ($raw.TrackNumber -eq '') { $null } else { $raw.TrackNumber }
        DiscNumber  = if ($raw.DiscNumber -eq '') { $null } else { $raw.DiscNumber }
        BPM         = if ($raw.BPM -eq '') { $null } else { $raw.BPM }
        Key         = $raw.Key
        Genre       = $raw.Genre
        Year        = if ($raw.Year -eq '') { $null } else { $raw.Year }
        ArtworkHash = $artworkHash
    }
}
