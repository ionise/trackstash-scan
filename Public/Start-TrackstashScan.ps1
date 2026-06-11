<#
.SYNOPSIS
Starts a filesystem scan and ingests audio metadata into SQLite.

.DESCRIPTION
Discovers supported media files under one or more roots, computes SHA256 file identity,
extracts metadata and fingerprint data through psMusicTagger cmdlets, and upserts the
result into the configured SQLite database. Errors are logged and scanning continues.

.PARAMETER Root
One or more root directories to scan for audio files.

.PARAMETER DatabasePath
Path to the SQLite database file. Defaults to ./trackstash-scan.db.

.PARAMETER Recurse
When set, scans subdirectories recursively.

.PARAMETER ForceRescan
When set, reprocesses files even if content hash already exists.

.PARAMETER ShowProgress
When set, displays PowerShell progress output while scanning.

.PARAMETER Resume
When set, uses scan checkpoints stored in SQLite to skip already processed
files from previous interrupted runs.

.OUTPUTS
PSCustomObject scan summary with counts and timestamps.

.EXAMPLE
Start-TrackstashScan -Root '/music/library' -Recurse -Verbose
#>
function Start-TrackstashScan {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string[]]$Root,

        [Parameter()]
        [string]$DatabasePath = './trackstash-scan.db',

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [switch]$ForceRescan,

        [Parameter()]
        [switch]$ShowProgress,

        [Parameter()]
        [switch]$Resume
    )

    $dbPath = Initialize-TrackstashDatabase -DatabasePath $DatabasePath
    $resolvedRoots = @($Root | ForEach-Object { [System.IO.Path]::GetFullPath($_) })

    $summary = [ordered]@{
        DatabasePath = $dbPath
        TotalFiles   = 0
        Processed    = 0
        Skipped      = 0
        Errors       = 0
        StartedUtc   = (Get-Date).ToUniversalTime()
        EndedUtc     = $null
    }

    $mediaFiles = @(Get-TrackstashMediaFiles -Root $Root -Recurse:$Recurse)
    $summary.TotalFiles = $mediaFiles.Count

    function Resolve-ScanRoot {
        param(
            [Parameter(Mandatory)]
            [string]$FilePath,
            [Parameter(Mandatory)]
            [string[]]$ScanRoots
        )

        $matchingRoots = @(
            $ScanRoots |
                Where-Object {
                    $FilePath -eq $_ -or $FilePath.StartsWith($_ + [System.IO.Path]::DirectorySeparatorChar)
                } |
                Sort-Object Length -Descending
        )

        if ($matchingRoots.Count -gt 0) {
            return $matchingRoots[0]
        }

        return [System.IO.Path]::GetDirectoryName($FilePath)
    }

    function Save-ScanCheckpoint {
        param(
            [Parameter(Mandatory)]
            [string]$CheckpointRoot,
            [Parameter(Mandatory)]
            [string]$FilePath,
            [AllowNull()]
            [string]$ContentHash
        )

        $checkpointQuery = @"
INSERT INTO scan_checkpoint (
    root,
    path,
    content_hash,
    checkpointed_utc
)
VALUES (
    @root,
    @path,
    @content_hash,
    @checkpointed_utc
)
ON CONFLICT(root, path)
DO UPDATE SET
    content_hash = excluded.content_hash,
    checkpointed_utc = excluded.checkpointed_utc;
"@

        [void](Invoke-SqliteQuery -DatabasePath $dbPath -Query $checkpointQuery -Parameters @{
            root             = $CheckpointRoot
            path             = $FilePath
            content_hash     = $ContentHash
            checkpointed_utc = (Get-Date).ToUniversalTime().ToString('o')
        } -QueryType NonQuery)
    }

    for ($index = 0; $index -lt $mediaFiles.Count; $index++) {
        $file = $mediaFiles[$index]
        $checkpointRoot = Resolve-ScanRoot -FilePath $file.Path -ScanRoots $resolvedRoots

        if ($ShowProgress) {
            $processedIndex = $index + 1
            $percentComplete = if ($summary.TotalFiles -gt 0) {
                [math]::Floor(($processedIndex / $summary.TotalFiles) * 100)
            }
            else {
                100
            }

            Write-Progress -Activity 'Scanning trackstash media files' -Status "$processedIndex of $($summary.TotalFiles)" -CurrentOperation $file.Path -PercentComplete $percentComplete
        }

        if (-not $PSCmdlet.ShouldProcess($file.Path, 'Scan and persist media metadata')) {
            $summary.Skipped++
            continue
        }

        try {
            if ($Resume) {
                $alreadyCheckpointed = Invoke-SqliteQuery -DatabasePath $dbPath -Query 'SELECT 1 FROM scan_checkpoint WHERE root = @root AND path = @path;' -Parameters @{ root = $checkpointRoot; path = $file.Path } -QueryType Scalar
                if ($alreadyCheckpointed) {
                    $summary.Skipped++
                    continue
                }
            }

            $contentHash = Get-TrackstashFileHash -Path $file.Path
            $existingId = Invoke-SqliteQuery -DatabasePath $dbPath -Query 'SELECT media_file_id FROM media_file WHERE content_hash = @content_hash;' -Parameters @{ content_hash = $contentHash } -QueryType Scalar

            if ($existingId -and -not $ForceRescan) {
                $updateExistingQuery = @"
UPDATE media_file
SET
    path = @path,
    size_bytes = @size_bytes,
    format = @format,
    last_modified_utc = @last_modified_utc,
    scanned_utc = @scanned_utc
WHERE content_hash = @content_hash;
"@
                [void](Invoke-SqliteQuery -DatabasePath $dbPath -Query $updateExistingQuery -Parameters @{
                    path              = $file.Path
                    size_bytes        = $file.SizeBytes
                    format            = $file.Format
                    last_modified_utc = $file.LastModifiedUtc.ToString('o')
                    scanned_utc       = (Get-Date).ToUniversalTime().ToString('o')
                    content_hash      = $contentHash
                } -QueryType NonQuery)

                if ($Resume) {
                    Save-ScanCheckpoint -CheckpointRoot $checkpointRoot -FilePath $file.Path -ContentHash $contentHash
                }

                $summary.Skipped++
                continue
            }

            $fingerprintInfo = Get-TrackstashFingerprint -Path $file.Path
            $metadata = Get-TrackstashMetadata -Path $file.Path

            $mediaRecord = [pscustomobject]@{
                ContentHash            = $contentHash
                Path                   = $file.Path
                FingerprintRaw         = $fingerprintInfo.FingerprintRaw
                AcoustIdSubmissionHash = $fingerprintInfo.AcoustIdSubmissionHash
                DurationSeconds        = $fingerprintInfo.DurationSeconds
                Format                 = $file.Format
                SizeBytes              = $file.SizeBytes
                LastModifiedUtc        = $file.LastModifiedUtc
                ScannedUtc             = (Get-Date).ToUniversalTime()
            }

            [void](Save-TrackstashRecord -DatabasePath $dbPath -MediaFile $mediaRecord -Metadata $metadata)

            if ($Resume) {
                Save-ScanCheckpoint -CheckpointRoot $checkpointRoot -FilePath $file.Path -ContentHash $contentHash
            }

            $summary.Processed++
        }
        catch {
            $summary.Errors++
            Write-TrackstashLog -Level Error -Message "Failed to process file '$($file.Path)': $($_.Exception.Message)"
            continue
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity 'Scanning trackstash media files' -Completed
    }

    if ($Resume) {
        foreach ($resolvedRoot in $resolvedRoots) {
            [void](Invoke-SqliteQuery -DatabasePath $dbPath -Query 'DELETE FROM scan_checkpoint WHERE root = @root;' -Parameters @{ root = $resolvedRoot } -QueryType NonQuery)
        }
    }

    $summary.EndedUtc = (Get-Date).ToUniversalTime()
    return [pscustomobject]$summary
}
