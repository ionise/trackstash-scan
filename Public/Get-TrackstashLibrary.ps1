<#!
.SYNOPSIS
Browse trackstash SQLite data as tracks or distinct library values.

.DESCRIPTION
Provides one command for common database lookups:
- track listings with optional filters (catalog number, ISRC, search text)
- distinct artists, labels, releases, catalog numbers, and ISRC values

.PARAMETER DatabasePath
Path to the SQLite database file.

.PARAMETER List
Result shape to return.

.PARAMETER Search
Contains search text.

.PARAMETER CatalogNumber
Filter by catalog number (tracks mode) or search value (catalog mode).

.PARAMETER Isrc
Filter by ISRC (tracks mode) or search value (isrc mode).

.PARAMETER Limit
Maximum rows to return.

.EXAMPLE
Get-TrackstashLibrary -DatabasePath ./trackstash-scan.db -List Labels

.EXAMPLE
Get-TrackstashLibrary -DatabasePath ./trackstash-scan.db -List Tracks -CatalogNumber ODST059
#>
function Get-TrackstashLibrary {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DatabasePath = './trackstash-scan.db',

        [Parameter()]
        [ValidateSet('Tracks', 'Artists', 'Labels', 'Releases', 'CatalogNumbers', 'Isrcs')]
        [string]$List = 'Tracks',

        [Parameter()]
        [string]$Search,

        [Parameter()]
        [string]$CatalogNumber,

        [Parameter()]
        [string]$Isrc,

        [Parameter()]
        [ValidateRange(1, 50000)]
        [int]$Limit = 500,

        [Parameter()]
        [switch]$ExactMatch
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($DatabasePath)
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "Database file not found: $resolvedPath"
    }

    $parameters = @{
        limit = $Limit
    }

    switch ($List) {
        'Tracks' {
            $whereClauses = @()

            if (-not [string]::IsNullOrWhiteSpace($CatalogNumber)) {
                if ($ExactMatch) {
                    $whereClauses += 'md.catalog_number = @catalog_number'
                    $parameters['catalog_number'] = $CatalogNumber.Trim()
                }
                else {
                    $whereClauses += 'md.catalog_number LIKE @catalog_number'
                    $parameters['catalog_number'] = "%$($CatalogNumber.Trim())%"
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($Isrc)) {
                if ($ExactMatch) {
                    $whereClauses += 'md.isrc = @isrc'
                    $parameters['isrc'] = $Isrc.Trim()
                }
                else {
                    $whereClauses += 'md.isrc LIKE @isrc'
                    $parameters['isrc'] = "%$($Isrc.Trim())%"
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($Search)) {
                $whereClauses += @"
(
    mf.path LIKE @search
    OR md.artist LIKE @search
    OR md.title LIKE @search
    OR md.album LIKE @search
    OR md.label LIKE @search
    OR md.release LIKE @search
    OR md.catalog_number LIKE @search
    OR md.isrc LIKE @search
)
"@
                $parameters['search'] = "%$($Search.Trim())%"
            }

            $query = @"
SELECT
    mf.media_file_id,
    mf.path,
    mf.format,
    mf.scanned_utc,
    md.artist,
    md.title,
    md.album,
    md.label,
    md.release,
    md.catalog_number,
    md.isrc,
    md.year
FROM media_file mf
LEFT JOIN metadata md
    ON md.media_file_id = mf.media_file_id
"@

            if ($whereClauses.Count -gt 0) {
                $query += "`nWHERE " + ($whereClauses -join "`nAND ")
            }

            $query += "`nORDER BY md.artist ASC, md.title ASC, mf.path ASC"
            $query += "`nLIMIT @limit;"

            return @(Invoke-SqliteQuery -DatabasePath $resolvedPath -Query $query -Parameters $parameters -QueryType Reader)
        }

        default {
            $columnMap = @{
                Artists        = 'md.artist'
                Labels         = 'md.label'
                Releases       = 'md.release'
                CatalogNumbers = 'md.catalog_number'
                Isrcs          = 'md.isrc'
            }

            $column = $columnMap[$List]
            $paramName = 'value_search'

            $whereClauses = @(
                "$column IS NOT NULL",
                "TRIM($column) <> ''"
            )

            $effectiveSearch = $Search
            if ($List -eq 'CatalogNumbers' -and -not [string]::IsNullOrWhiteSpace($CatalogNumber)) {
                $effectiveSearch = $CatalogNumber
            }
            if ($List -eq 'Isrcs' -and -not [string]::IsNullOrWhiteSpace($Isrc)) {
                $effectiveSearch = $Isrc
            }

            if (-not [string]::IsNullOrWhiteSpace($effectiveSearch)) {
                if ($ExactMatch) {
                    $whereClauses += "$column = @$paramName"
                    $parameters[$paramName] = $effectiveSearch.Trim()
                }
                else {
                    $whereClauses += "$column LIKE @$paramName"
                    $parameters[$paramName] = "%$($effectiveSearch.Trim())%"
                }
            }

            $query = @"
SELECT
    TRIM($column) AS value,
    COUNT(*) AS tracks
FROM metadata md
WHERE $($whereClauses -join "`n  AND ")
GROUP BY TRIM($column)
ORDER BY tracks DESC, value ASC
LIMIT @limit;
"@

            return @(Invoke-SqliteQuery -DatabasePath $resolvedPath -Query $query -Parameters $parameters -QueryType Reader)
        }
    }
}
