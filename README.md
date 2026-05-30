# trackstash-scan

trackstash-scan is a PowerShell 7.4+ scanner that:

- Walks one or more filesystem roots for supported audio files.
- Uses psMusicTagger cmdlets for metadata and fingerprint extraction.
- Computes SHA256 content hashes.
- Persists media and metadata records into SQLite using Microsoft.Data.Sqlite.

## Features

- Supported formats: `.flac`, `.mp3`, `.wav`, `.aiff`, `.m4a`, `.ogg`
- Canonical identity: SHA256 content hash
- Idempotent ingest: upserts by content hash
- Continue-on-error behavior with logging
- Module functions plus CLI entry script

## Requirements

- PowerShell 7.4+
- psMusicTagger module available in the PowerShell session
- Microsoft.Data.Sqlite assembly available to PowerShell
- Pester 5 (for running tests)

## First-Run Bootstrap

Use the bootstrap script to install dependencies automatically:

```powershell
pwsh ./scripts/Install-TrackstashScanDependencies.ps1
```

Optional parameters:

- `-Scope CurrentUser|AllUsers` for psMusicTagger install scope (default `CurrentUser`)
- `-SqliteVersion <version>` to pin Microsoft.Data.Sqlite package version
- `-Force` to force reinstall/overwrite

Example:

```powershell
pwsh ./scripts/Install-TrackstashScanDependencies.ps1 -Scope CurrentUser -SqliteVersion 8.0.7 -Force
```

## Project Layout

- [trackstash-scan.psd1](trackstash-scan.psd1)
- [trackstash-scan.psm1](trackstash-scan.psm1)
- [Public](Public)
- [Private](Private)
- [CLI/trackstash-scan.ps1](CLI/trackstash-scan.ps1)
- [Tests](Tests)

## Import the Module

```powershell
Import-Module ./trackstash-scan.psd1 -Force
Get-Command -Module trackstash-scan
```

## CLI Usage

The CLI script is [CLI/trackstash-scan.ps1](CLI/trackstash-scan.ps1).

```powershell
pwsh ./CLI/trackstash-scan.ps1 -Root '/path/to/music' -Recurse -Verbose
```

Parameters:

- `-Root <string[]>` (required): one or more scan roots
- `-DatabasePath <string>`: SQLite file path (default `./trackstash-scan.db`)
- `-Recurse`: recurse through subdirectories
- `-ForceRescan`: recompute metadata and fingerprint even if hash exists
- `-Verbose`: write informational logs
- `-WhatIf`: dry-run mode through ShouldProcess

Examples:

```powershell
pwsh ./CLI/trackstash-scan.ps1 -Root '/Volumes/Music' -Recurse
pwsh ./CLI/trackstash-scan.ps1 -Root '/Volumes/Music','/Volumes/Archive' -Recurse -DatabasePath './data/trackstash-scan.db'
pwsh ./CLI/trackstash-scan.ps1 -Root '/Volumes/Music' -Recurse -ForceRescan -Verbose
pwsh ./CLI/trackstash-scan.ps1 -Root '/Volumes/Music' -Recurse -WhatIf
```

## Module Function Usage

Start a scan:

```powershell
Start-TrackstashScan -Root '/path/to/music' -Recurse -DatabasePath './trackstash-scan.db'
```

List candidate media files only:

```powershell
Get-TrackstashMediaFiles -Root '/path/to/music' -Recurse
```

Hash a single file:

```powershell
Get-TrackstashFileHash -Path '/path/to/file.flac'
```

Extract normalized metadata:

```powershell
Get-TrackstashMetadata -Path '/path/to/file.mp3'
```

Extract fingerprint data:

```powershell
Get-TrackstashFingerprint -Path '/path/to/file.ogg'
```

## Database Schema

Tables:

- `media_file`
- `metadata`

`media_file` stores:

- `content_hash` (UNIQUE)
- `path`
- `fingerprint_raw`
- `acoustid_submission_hash`
- `duration_seconds`
- `format`
- `size_bytes`
- `last_modified_utc`
- `scanned_utc`

`metadata` stores normalized tags keyed by `media_file_id`.

## Running Tests

```powershell
Invoke-Pester -Path ./Tests -Output Detailed
```

## Notes

- Missing tags are written as SQL `NULL`.
- If artwork hash is not exposed by psMusicTagger metadata output, `artwork_hash` remains `NULL`.
- Scanning continues when an individual file fails; errors are logged.
