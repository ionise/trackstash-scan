<#
.SYNOPSIS
Returns checkpoint status for resumable scans.

.DESCRIPTION
Reads checkpoint information from the scan_checkpoint table and returns summary
and per-root counts so you can measure how much resume progress exists before
starting a scan with -Resume.

.PARAMETER DatabasePath
Path to the SQLite database file. Defaults to ./trackstash-scan.db.

.PARAMETER Root
Optional root filter. When provided, only checkpoints for these roots are
returned.

.PARAMETER IncludeRecentPaths
When set, includes a RecentPaths property with the most recent checkpointed
files for the selected roots.

.PARAMETER RecentPathLimit
Maximum number of recent paths returned when IncludeRecentPaths is set.

.OUTPUTS
PSCustomObject checkpoint status details.

.EXAMPLE
Get-TrackstashScanCheckpointStatus -DatabasePath './trackstash-scan.db'

.EXAMPLE
Get-TrackstashScanCheckpointStatus -DatabasePath './trackstash-scan.db' -Root '/Volumes/music/Backup' -IncludeRecentPaths
#>
function Get-TrackstashScanCheckpointStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DatabasePath = './trackstash-scan.db',

        [Parameter()]
        [string[]]$Root,

        [Parameter()]
        [switch]$IncludeRecentPaths,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$RecentPathLimit = 50
    )

    $dbPath = Initialize-TrackstashDatabase -DatabasePath $DatabasePath

    $whereClauses = @()
    $parameters = @{}

    if ($Root -and $Root.Count -gt 0) {
        $resolvedRoots = @($Root | ForEach-Object { [System.IO.Path]::GetFullPath($_) })
        $placeholders = @()

        for ($i = 0; $i -lt $resolvedRoots.Count; $i++) {
            $paramName = "root_$i"
            $placeholders += "@$paramName"
            $parameters[$paramName] = $resolvedRoots[$i]
        }

        $whereClauses += "root IN (" + ($placeholders -join ', ') + ")"
    }

    $whereSql = ''
    if ($whereClauses.Count -gt 0) {
        $whereSql = "WHERE " + ($whereClauses -join ' AND ')
    }

    $summaryQuery = @"
SELECT
    COUNT(*) AS total_checkpoints,
    COUNT(DISTINCT root) AS roots_with_checkpoints,
    MIN(checkpointed_utc) AS oldest_checkpoint_utc,
    MAX(checkpointed_utc) AS newest_checkpoint_utc
FROM scan_checkpoint
$whereSql;
"@

    $summaryRows = @(Invoke-SqliteQuery -DatabasePath $dbPath -Query $summaryQuery -Parameters $parameters -QueryType Reader)
    $summaryRow = if ($summaryRows.Count -gt 0) { $summaryRows[0] } else { $null }

    $perRootQuery = @"
SELECT
    root,
    COUNT(*) AS checkpoint_count,
    MIN(checkpointed_utc) AS oldest_checkpoint_utc,
    MAX(checkpointed_utc) AS newest_checkpoint_utc
FROM scan_checkpoint
$whereSql
GROUP BY root
ORDER BY checkpoint_count DESC, root ASC;
"@

    $byRoot = @(Invoke-SqliteQuery -DatabasePath $dbPath -Query $perRootQuery -Parameters $parameters -QueryType Reader)

    $recentPaths = @()
    if ($IncludeRecentPaths) {
        $recentQuery = @"
SELECT
    root,
    path,
    content_hash,
    checkpointed_utc
FROM scan_checkpoint
$whereSql
ORDER BY checkpointed_utc DESC
LIMIT @recent_limit;
"@

        $recentParams = @{}
        foreach ($key in $parameters.Keys) {
            $recentParams[$key] = $parameters[$key]
        }
        $recentParams['recent_limit'] = $RecentPathLimit

        $recentPaths = @(Invoke-SqliteQuery -DatabasePath $dbPath -Query $recentQuery -Parameters $recentParams -QueryType Reader)
    }

    return [pscustomobject]@{
        DatabasePath         = $dbPath
        TotalCheckpoints     = if ($summaryRow) { [int]$summaryRow.total_checkpoints } else { 0 }
        RootsWithCheckpoints = if ($summaryRow) { [int]$summaryRow.roots_with_checkpoints } else { 0 }
        OldestCheckpointUtc  = if ($summaryRow) { $summaryRow.oldest_checkpoint_utc } else { $null }
        NewestCheckpointUtc  = if ($summaryRow) { $summaryRow.newest_checkpoint_utc } else { $null }
        ByRoot               = $byRoot
        RecentPaths          = $recentPaths
    }
}
