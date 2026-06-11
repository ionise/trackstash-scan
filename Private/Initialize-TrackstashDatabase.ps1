<#
.SYNOPSIS
Initializes the SQLite database and required schema.

.DESCRIPTION
Creates the database file and parent directory when missing, then creates
media_file and metadata tables if they do not already exist.

.PARAMETER DatabasePath
Path to the SQLite database file.

.OUTPUTS
String full path to the initialized database.

.EXAMPLE
Initialize-TrackstashDatabase -DatabasePath './trackstash-scan.db'
#>
function Initialize-TrackstashDatabase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($DatabasePath)
    $parent = Split-Path -Path $resolvedPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        New-Item -ItemType File -Path $resolvedPath -Force | Out-Null
    }

    $schema = @"
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS media_file (
    media_file_id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_hash TEXT NOT NULL UNIQUE,
    path TEXT NOT NULL,
    fingerprint_raw TEXT NULL,
    acoustid_submission_hash TEXT NULL,
    duration_seconds REAL NULL,
    format TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    last_modified_utc TEXT NOT NULL,
    scanned_utc TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS metadata (
    metadata_id INTEGER PRIMARY KEY AUTOINCREMENT,
    media_file_id INTEGER NOT NULL UNIQUE,
    artist TEXT NULL,
    title TEXT NULL,
    album TEXT NULL,
    label TEXT NULL,
    release TEXT NULL,
    isrc TEXT NULL,
    barcode TEXT NULL,
    catalog_number TEXT NULL,
    track_number INTEGER NULL,
    disc_number INTEGER NULL,
    bpm REAL NULL,
    musical_key TEXT NULL,
    genre TEXT NULL,
    year INTEGER NULL,
    artwork_hash TEXT NULL,
    FOREIGN KEY(media_file_id) REFERENCES media_file(media_file_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS scan_checkpoint (
    root TEXT NOT NULL,
    path TEXT NOT NULL,
    content_hash TEXT NULL,
    checkpointed_utc TEXT NOT NULL,
    PRIMARY KEY (root, path)
);
"@

    [void](Invoke-SqliteQuery -DatabasePath $resolvedPath -Query $schema -QueryType NonQuery)

    $metadataColumns = @(Invoke-SqliteQuery -DatabasePath $resolvedPath -Query 'PRAGMA table_info(metadata);' -QueryType Reader)
    $metadataColumnNames = @(
        $metadataColumns |
            Where-Object { $_ -and $_.PSObject.Properties['name'] } |
            ForEach-Object { "$($_.name)" }
    )

    if ($metadataColumnNames -notcontains 'isrc') {
        [void](Invoke-SqliteQuery -DatabasePath $resolvedPath -Query 'ALTER TABLE metadata ADD COLUMN isrc TEXT NULL;' -QueryType NonQuery)
    }

    if ($metadataColumnNames -notcontains 'barcode') {
        [void](Invoke-SqliteQuery -DatabasePath $resolvedPath -Query 'ALTER TABLE metadata ADD COLUMN barcode TEXT NULL;' -QueryType NonQuery)
    }

    if ($metadataColumnNames -notcontains 'catalog_number') {
        [void](Invoke-SqliteQuery -DatabasePath $resolvedPath -Query 'ALTER TABLE metadata ADD COLUMN catalog_number TEXT NULL;' -QueryType NonQuery)
    }

    return $resolvedPath
}
