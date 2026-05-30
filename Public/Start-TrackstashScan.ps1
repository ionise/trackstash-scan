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
        [switch]$ForceRescan
    )

    $dbPath = Initialize-TrackstashDatabase -DatabasePath $DatabasePath

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

    foreach ($file in $mediaFiles) {
        if (-not $PSCmdlet.ShouldProcess($file.Path, 'Scan and persist media metadata')) {
            $summary.Skipped++
            continue
        }

        try {
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
            $summary.Processed++
        }
        catch {
            $summary.Errors++
            Write-TrackstashLog -Level Error -Message "Failed to process file '$($file.Path)': $($_.Exception.Message)"
            continue
        }
    }

    $summary.EndedUtc = (Get-Date).ToUniversalTime()
    return [pscustomobject]$summary
}
