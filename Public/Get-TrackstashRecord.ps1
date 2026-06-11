<#
.SYNOPSIS
Queries trackstash records from SQLite with filter and search options.

.DESCRIPTION
Returns joined media and metadata rows from trackstash-scan.db. Supports field
filters, free-text search across common columns, numeric range filters, and
controllable sort/limit behavior.

.PARAMETER DatabasePath
Path to the SQLite database file. Defaults to ./trackstash-scan.db.

.PARAMETER Search
Free-text contains search across path, content_hash, artist, title, album,
label, release, isrc, barcode, catalog_number, and genre.

.PARAMETER ExactMatch
When set, string field filters use exact match instead of contains matching.

.PARAMETER Limit
Maximum number of rows returned. Default 500.

.OUTPUTS
PSCustomObject query rows.

.EXAMPLE
Get-TrackstashRecord -DatabasePath './trackstash-scan.db' -Artist 'Calibre'

.EXAMPLE
Get-TrackstashRecord -Search 'Hospital Records' -Genre 'Drum & Bass' -MinYear 2015
#>
function Get-TrackstashRecord {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DatabasePath = './trackstash-scan.db',

        [Parameter()]
        [string]$Search,

        [Parameter()]
        [string]$Artist,

        [Parameter()]
        [string]$Title,

        [Parameter()]
        [string]$Album,

        [Parameter()]
        [string]$Label,

        [Parameter()]
        [string]$Release,

        [Parameter()]
        [string]$Isrc,

        [Parameter()]
        [string]$Barcode,

        [Parameter()]
        [string]$CatalogNumber,

        [Parameter()]
        [string]$Genre,

        [Parameter()]
        [string]$Format,

        [Parameter()]
        [string]$Path,

        [Parameter()]
        [string]$ContentHash,

        [Parameter()]
        [int]$MinYear,

        [Parameter()]
        [int]$MaxYear,

        [Parameter()]
        [double]$MinBPM,

        [Parameter()]
        [double]$MaxBPM,

        [Parameter()]
        [ValidateRange(1, 50000)]
        [int]$Limit = 500,

        [Parameter()]
        [ValidateSet('scanned_utc', 'path', 'artist', 'title', 'album', 'label', 'year', 'bpm')]
        [string]$OrderBy = 'scanned_utc',

        [Parameter()]
        [switch]$Descending,

        [Parameter()]
        [switch]$ExactMatch
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($DatabasePath)
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "Database file not found: $resolvedPath"
    }

    $whereClauses = @()
    $parameters = @{}

    function Add-TextFilter {
        param(
            [Parameter(Mandatory)]
            [string]$Column,
            [Parameter(Mandatory)]
            [string]$ParamName,
            [Parameter()]
            [AllowNull()]
            [string]$Value,
            [Parameter()]
            [switch]$UseExact
        )

        if ([string]::IsNullOrWhiteSpace($Value)) {
            return
        }

        if ($UseExact) {
            return [pscustomobject]@{
                Clause = "$Column = @$ParamName"
                Name   = $ParamName
                Value  = $Value.Trim()
            }
        }

        return [pscustomobject]@{
            Clause = "$Column LIKE @$ParamName"
            Name   = $ParamName
            Value  = "%$($Value.Trim())%"
        }
    }

    $textFilters = @(
        Add-TextFilter -Column 'md.artist' -ParamName 'artist' -Value $Artist -UseExact:$ExactMatch
        Add-TextFilter -Column 'md.title' -ParamName 'title' -Value $Title -UseExact:$ExactMatch
        Add-TextFilter -Column 'md.album' -ParamName 'album' -Value $Album -UseExact:$ExactMatch
        Add-TextFilter -Column 'md.label' -ParamName 'label' -Value $Label -UseExact:$ExactMatch
        Add-TextFilter -Column 'md.release' -ParamName 'release' -Value $Release -UseExact:$ExactMatch
        Add-TextFilter -Column 'md.isrc' -ParamName 'isrc' -Value $Isrc -UseExact:$ExactMatch
        Add-TextFilter -Column 'md.barcode' -ParamName 'barcode' -Value $Barcode -UseExact:$ExactMatch
        Add-TextFilter -Column 'md.catalog_number' -ParamName 'catalog_number' -Value $CatalogNumber -UseExact:$ExactMatch
        Add-TextFilter -Column 'md.genre' -ParamName 'genre' -Value $Genre -UseExact:$ExactMatch
        Add-TextFilter -Column 'mf.format' -ParamName 'format' -Value $Format -UseExact:$ExactMatch
        Add-TextFilter -Column 'mf.path' -ParamName 'path' -Value $Path -UseExact:$ExactMatch
        Add-TextFilter -Column 'mf.content_hash' -ParamName 'content_hash' -Value $ContentHash -UseExact:$ExactMatch
    )

    foreach ($filter in $textFilters) {
        if ($null -eq $filter) {
            continue
        }

        $whereClauses += $filter.Clause
        $parameters[$filter.Name] = $filter.Value
    }

    if ($PSBoundParameters.ContainsKey('MinYear')) {
        $whereClauses += 'md.year >= @min_year'
        $parameters['min_year'] = $MinYear
    }

    if ($PSBoundParameters.ContainsKey('MaxYear')) {
        $whereClauses += 'md.year <= @max_year'
        $parameters['max_year'] = $MaxYear
    }

    if ($PSBoundParameters.ContainsKey('MinBPM')) {
        $whereClauses += 'md.bpm >= @min_bpm'
        $parameters['min_bpm'] = $MinBPM
    }

    if ($PSBoundParameters.ContainsKey('MaxBPM')) {
        $whereClauses += 'md.bpm <= @max_bpm'
        $parameters['max_bpm'] = $MaxBPM
    }

    if (-not [string]::IsNullOrWhiteSpace($Search)) {
        $whereClauses += @"
(
    mf.path LIKE @search
    OR mf.content_hash LIKE @search
    OR md.artist LIKE @search
    OR md.title LIKE @search
    OR md.album LIKE @search
    OR md.label LIKE @search
    OR md.release LIKE @search
    OR md.isrc LIKE @search
    OR md.barcode LIKE @search
    OR md.catalog_number LIKE @search
    OR md.genre LIKE @search
)
"@
        $parameters['search'] = "%$($Search.Trim())%"
    }

    $orderByColumnMap = @{
        scanned_utc = 'mf.scanned_utc'
        path        = 'mf.path'
        artist      = 'md.artist'
        title       = 'md.title'
        album       = 'md.album'
        label       = 'md.label'
        year        = 'md.year'
        bpm         = 'md.bpm'
    }

    $orderByColumn = $orderByColumnMap[$OrderBy]
    $orderDirection = if ($Descending) { 'DESC' } else { 'ASC' }

    $query = @"
SELECT
    mf.media_file_id,
    mf.content_hash,
    mf.path,
    mf.fingerprint_raw,
    mf.acoustid_submission_hash,
    mf.duration_seconds,
    mf.format,
    mf.size_bytes,
    mf.last_modified_utc,
    mf.scanned_utc,
    md.artist,
    md.title,
    md.album,
    md.label,
    md.release,
    md.isrc,
    md.barcode,
    md.catalog_number,
    md.track_number,
    md.disc_number,
    md.bpm,
    md.musical_key,
    md.genre,
    md.year,
    md.artwork_hash
FROM media_file mf
LEFT JOIN metadata md
    ON md.media_file_id = mf.media_file_id
"@

    if ($whereClauses.Count -gt 0) {
        $query += "`nWHERE " + ($whereClauses -join "`nAND ")
    }

    $query += "`nORDER BY $orderByColumn $orderDirection"
    $query += "`nLIMIT @limit;"
    $parameters['limit'] = $Limit

    return @(Invoke-SqliteQuery -DatabasePath $resolvedPath -Query $query -Parameters $parameters -QueryType Reader)
}
