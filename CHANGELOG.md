# Changelog

All notable changes to `trackstash-scan` will be documented in this file.

## Unreleased

### Added
- `Get-TrackstashLibrary` for querying the scan database by artist, album, label, genre, year, hash, and path-related filters.
- `Get-TrackstashRecord` for richer record lookup and search against stored scan data.
- `Get-TrackstashScanCheckpointStatus` for inspecting checkpoint/resume state.
- `-Resume` support in `Start-TrackstashScan` and the CLI wrapper.
- `-ShowProgress` support for interactive progress reporting.
- `Tests/CheckpointStatus.Tests.ps1`, `Tests/Query.Tests.ps1`, and `Tests/Logging.Tests.ps1`.

### Changed
- Expanded the SQLite schema bootstrap to include `scan_checkpoint` support.
- Improved scan logging and checkpoint handling.
- Extended `Get-TrackstashMetadata` and `Save-TrackstashRecord` to support the new query and storage flow.
- Updated the module manifest and exports to surface the new public commands.
- Expanded the README with new command usage, schema notes, and workflow examples.

### Fixed
- Improved idempotent scan behavior for interrupted runs.
- Added more complete database and metadata test coverage around the new query and checkpoint paths.

### Notes
- The broader schema, catalog, and matching design documentation has moved into `trackstash-core/docs` to keep the scan module focused on filesystem ingestion.
