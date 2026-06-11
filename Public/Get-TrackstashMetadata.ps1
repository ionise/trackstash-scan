<#
.SYNOPSIS
Extracts and normalizes audio metadata using psMusicTagger.

.DESCRIPTION
Calls psMusicTagger metadata cmdlets and maps tag fields to a consistent schema
expected by trackstash-scan. Missing values are normalized to null where
applicable.

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

    if (Get-Command -Name 'Get-TrackMetadata' -ErrorAction SilentlyContinue) {
        $raw = Get-TrackMetadata -FilePath $Path -ErrorAction Stop
    }
    elseif (Get-Command -Name 'Get-MusicMetadata' -ErrorAction SilentlyContinue) {
        $raw = Get-MusicMetadata -Path $Path -ErrorAction Stop
    }
    else {
        throw 'No supported metadata cmdlet found. Expected Get-MusicMetadata or Get-TrackMetadata from psMusicTagger.'
    }

    function Get-TagValue {
        param(
            [Parameter(Mandatory)]
            [object]$Source,
            [Parameter(Mandatory)]
            [string[]]$Names
        )

        foreach ($name in $Names) {
            $prop = $Source.PSObject.Properties[$name]
            if ($null -ne $prop) {
                $value = $prop.Value
                if ($null -eq $value) {
                    continue
                }

                if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
                    continue
                }

                return $value
            }
        }

        return $null
    }

    function Normalize-TagValue {
        param([object]$Value)

        if ($null -eq $Value) {
            return $null
        }

        if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) {
            return $null
        }

        return $Value
    }

    $artworkHash = Get-TagValue -Source $raw -Names @('ArtworkHash')
    $album = Normalize-TagValue (Get-TagValue -Source $raw -Names @('Album'))
    $release = Normalize-TagValue (Get-TagValue -Source $raw -Names @('Release'))
    if ($null -eq $release) {
        $release = $album
    }

    return [pscustomobject]@{
        Artist      = Normalize-TagValue (Get-TagValue -Source $raw -Names @('Artist', 'AlbumArtist'))
        Title       = Normalize-TagValue (Get-TagValue -Source $raw -Names @('Title'))
        Album       = $album
        Label       = Normalize-TagValue (Get-TagValue -Source $raw -Names @('Label', 'Publisher'))
        Release     = $release
        Isrc        = Normalize-TagValue (Get-TagValue -Source $raw -Names @('ISRC', 'Isrc'))
        Barcode     = Normalize-TagValue (Get-TagValue -Source $raw -Names @('Barcode', 'UPC', 'EAN'))
        CatalogNumber = Normalize-TagValue (Get-TagValue -Source $raw -Names @('CatalogNumber', 'CatalogNo', 'Catalog', 'CatNo', 'CATALOG_NUMBER'))
        TrackNumber = Normalize-TagValue (Get-TagValue -Source $raw -Names @('TrackNumber', 'Track'))
        DiscNumber  = Normalize-TagValue (Get-TagValue -Source $raw -Names @('DiscNumber', 'Disc'))
        BPM         = Normalize-TagValue (Get-TagValue -Source $raw -Names @('BPM', 'Tempo', 'BeatsPerMinute'))
        Key         = Normalize-TagValue (Get-TagValue -Source $raw -Names @('Key', 'InitialKey'))
        Genre       = Normalize-TagValue (Get-TagValue -Source $raw -Names @('Genre'))
        Year        = Normalize-TagValue (Get-TagValue -Source $raw -Names @('Year', 'Date'))
        ArtworkHash = Normalize-TagValue $artworkHash
    }
}
