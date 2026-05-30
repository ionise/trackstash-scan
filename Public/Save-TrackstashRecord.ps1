<#
.SYNOPSIS
Upserts media and metadata records into SQLite.

.DESCRIPTION
Ensures database schema exists, then writes media_file and metadata rows using
content_hash as canonical identity with conflict-based updates.

.PARAMETER DatabasePath
Path to the SQLite database file.

.PARAMETER MediaFile
Media file record object containing identity and scan attributes.

.PARAMETER Metadata
Normalized metadata object for the media file.

.OUTPUTS
Int32 media_file_id for the upserted record.

.EXAMPLE
Save-TrackstashRecord -DatabasePath './trackstash-scan.db' -MediaFile $media -Metadata $tags
#>
function Save-TrackstashRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [Parameter(Mandatory)]
        [pscustomobject]$MediaFile,

        [Parameter(Mandatory)]
        [pscustomobject]$Metadata
    )

    $dbPath = Initialize-TrackstashDatabase -DatabasePath $DatabasePath

    $upsertMediaFileQuery = @"
INSERT INTO media_file (
    content_hash,
    path,
    fingerprint_raw,
    acoustid_submission_hash,
    duration_seconds,
    format,
    size_bytes,
    last_modified_utc,
    scanned_utc
)
VALUES (
    @content_hash,
    @path,
    @fingerprint_raw,
    @acoustid_submission_hash,
    @duration_seconds,
    @format,
    @size_bytes,
    @last_modified_utc,
    @scanned_utc
)
ON CONFLICT(content_hash)
DO UPDATE SET
    path = excluded.path,
    fingerprint_raw = excluded.fingerprint_raw,
    acoustid_submission_hash = excluded.acoustid_submission_hash,
    duration_seconds = excluded.duration_seconds,
    format = excluded.format,
    size_bytes = excluded.size_bytes,
    last_modified_utc = excluded.last_modified_utc,
    scanned_utc = excluded.scanned_utc;
"@

    $mediaParams = @{
        content_hash            = $MediaFile.ContentHash
        path                    = $MediaFile.Path
        fingerprint_raw         = $MediaFile.FingerprintRaw
        acoustid_submission_hash = $MediaFile.AcoustIdSubmissionHash
        duration_seconds        = $MediaFile.DurationSeconds
        format                  = $MediaFile.Format
        size_bytes              = $MediaFile.SizeBytes
        last_modified_utc       = $MediaFile.LastModifiedUtc.ToString('o')
        scanned_utc             = $MediaFile.ScannedUtc.ToString('o')
    }

    [void](Invoke-SqliteQuery -DatabasePath $dbPath -Query $upsertMediaFileQuery -Parameters $mediaParams -QueryType NonQuery)

    $mediaFileId = Invoke-SqliteQuery -DatabasePath $dbPath -Query 'SELECT media_file_id FROM media_file WHERE content_hash = @content_hash;' -Parameters @{ content_hash = $MediaFile.ContentHash } -QueryType Scalar

    $upsertMetadataQuery = @"
INSERT INTO metadata (
    media_file_id,
    artist,
    title,
    album,
    label,
    release,
    track_number,
    disc_number,
    bpm,
    musical_key,
    genre,
    year,
    artwork_hash
)
VALUES (
    @media_file_id,
    @artist,
    @title,
    @album,
    @label,
    @release,
    @track_number,
    @disc_number,
    @bpm,
    @musical_key,
    @genre,
    @year,
    @artwork_hash
)
ON CONFLICT(media_file_id)
DO UPDATE SET
    artist = excluded.artist,
    title = excluded.title,
    album = excluded.album,
    label = excluded.label,
    release = excluded.release,
    track_number = excluded.track_number,
    disc_number = excluded.disc_number,
    bpm = excluded.bpm,
    musical_key = excluded.musical_key,
    genre = excluded.genre,
    year = excluded.year,
    artwork_hash = excluded.artwork_hash;
"@

    $metadataParams = @{
        media_file_id = $mediaFileId
        artist        = $Metadata.Artist
        title         = $Metadata.Title
        album         = $Metadata.Album
        label         = $Metadata.Label
        release       = $Metadata.Release
        track_number  = $Metadata.TrackNumber
        disc_number   = $Metadata.DiscNumber
        bpm           = $Metadata.BPM
        musical_key   = $Metadata.Key
        genre         = $Metadata.Genre
        year          = $Metadata.Year
        artwork_hash  = $Metadata.ArtworkHash
    }

    [void](Invoke-SqliteQuery -DatabasePath $dbPath -Query $upsertMetadataQuery -Parameters $metadataParams -QueryType NonQuery)

    return $mediaFileId
}
