# GitHub Copilot Project Prompt: trackstash-scan

You are assisting with the implementation of **trackstash-scan**, a standalone PowerShell tool in the TrackStash-Lite ecosystem.

## Purpose
trackstash-scan has ONE responsibility:
Scan the filesystem for audio media files, extract metadata using the existing **psMusicTagger** module, compute file hashes and AcoustID-compatible fingerprints, and store the results in a SQLite database.

## Mandatory Dependencies
- The PowerShell module **psMusicTagger** (https://github.com/ionise/psmusictagger)
- Copilot must call psMusicTagger cmdlets instead of reimplementing metadata parsing or fingerprinting.

## Required psMusicTagger Cmdlets
Use these cmdlets directly:
- `Get-MusicMetadata` — extract embedded tags
- `Get-AudioFingerprint` — compute Chromaprint/AcoustID-compatible fingerprint
- `Get-AudioDuration` — duration helper
- Any other psMusicTagger utilities as needed

Copilot must NOT write its own tag readers or fingerprinting logic.

## Functional Requirements

### 1. Filesystem scanning
- Recursively walk one or more root directories.
- Detect supported audio formats: `.flac`, `.mp3`, `.wav`, `.aiff`, `.m4a`, `.ogg`.
- Capture file path, size, last modified timestamp.

### 2. Metadata extraction (via psMusicTagger)
- Call `Get-MusicMetadata -Path <file>`
- Normalise tag fields into a consistent schema:
  - Artist, Title, Album, Label, Release, TrackNumber, DiscNumber
  - BPM, Key, Genre, Year
  - ArtworkHash (not artwork data)
- Do not attempt to parse tags manually.

### 3. File identity
- Compute a stable file hash (SHA256 or xxHash64).
- Compute fingerprint using:
  - `Get-AudioFingerprint -Path <file>`
- Store both raw fingerprint and AcoustID submission hash if needed.

### 4. Database storage (SQLite)
- Use SQLite as the local store.
- Required tables:
  - `media_file` (path, hash, fingerprint, duration, format, size, timestamps)
  - `metadata` (normalised tag fields)
- Idempotent ingest: scanning the same file twice must update, not duplicate.

### 5. Non-goals (Copilot must NOT generate code for these)
- No embeddings
- No similarity search
- No playlist logic
- No API calls
- No cloud sync
- No UI
- No business logic outside scanning

## Architectural Principles
- Single responsibility: scanning only.
- Deterministic output: same file → same hash → same fingerprint.
- Modular: scanning logic must be isolated so other TrackStash modules can call it.
- Avoid side effects except writing to the database.
- Prefer pure functions where possible.

## Coding Style
- Clean, modular PowerShell.
- Small functions with clear names.
- Use psMusicTagger cmdlets directly.
- Add comments/docstrings explaining assumptions.
- Avoid unnecessary abstractions.

## What Copilot Should Generate
- Directory walking logic
- Calls to psMusicTagger for metadata + fingerprint
- Hashing utilities
- SQLite schema + ingestion code
- CLI entry point
- Unit tests for each component

## What Copilot Should Avoid
- Reimplementing metadata parsing
- Reimplementing Chromaprint
- Adding unrelated TrackStash features
- Adding network calls
- Adding GUI or web components

Follow this prompt strictly.
