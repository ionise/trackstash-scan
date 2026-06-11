# trackstash-scan TODO

## Completed (2026-06-01)

- Added `-ShowProgress` support to `Start-TrackstashScan` and CLI wrapper.
- Added `-Resume` support backed by SQLite `scan_checkpoint` table.

## Scan progress reporting (implemented)

**Goal:** Give visibility into how far a scan has progressed through a large library.

**Design decisions:**
- Use PowerShell's native `Write-Progress` for the progress bar (works in both interactive terminal and VS Code) — no extra dependencies.
- Also emit verbose log lines per file when `-Verbose` is set, so progress is visible in non-interactive/piped contexts.
- Total file count is already computed before the loop in `Start-TrackstashScan`, so `PercentComplete` and `CurrentOperation` can be set accurately on each iteration.
- A new `-ShowProgress` switch on `Start-TrackstashScan` and the CLI script to opt in (avoids noise in unattended runs).

**Files to change:**
- `Public/Start-TrackstashScan.ps1` — add `-ShowProgress` switch, call `Write-Progress` inside the loop
- `CLI/trackstash-scan.ps1` — expose `-ShowProgress`
- `README.md` — document new switch
- `Tests/Start-TrackstashScan.Tests.ps1` — test progress not thrown when enabled

---

## Scan checkpoint / resume (implemented)

**Goal:** Allow a scan interrupted mid-way to resume from where it left off rather than restarting from the beginning.

**Design decisions:**
- Store checkpoint state in the same SQLite database in a new `scan_checkpoint` table — no extra files to manage, transactional, works with the existing `Invoke-SqliteQuery` helper.
- Schema: `(root TEXT, path TEXT, content_hash TEXT, checkpointed_utc TEXT, PRIMARY KEY (root, path))`
- A file is checkpointed when it has been successfully processed (either persisted or skipped because its hash was already in `media_file`).
- On resume, the scanner checks `scan_checkpoint` for `(root, path)` before hashing. If found, the file is skipped cheaply.
- Checkpoint rows are deleted when the scan completes cleanly so stale entries don't accumulate. On interruption they remain to enable resume.
- A new `-Resume` switch on `Start-TrackstashScan` and the CLI script to opt in. Without it, checkpoint table is ignored and a full scan runs.

**Files to change:**
- `Private/Initialize-TrackstashDatabase.ps1` — add `scan_checkpoint` table to schema
- `Public/Start-TrackstashScan.ps1` — add `-Resume` switch, checkpoint write after each file, skip if already checkpointed, clear on clean completion
- `CLI/trackstash-scan.ps1` — expose `-Resume`
- `README.md` — document new switch
- `Tests/Start-TrackstashScan.Tests.ps1` — test resume skips checkpointed files; test checkpoint cleared on clean finish
- `Tests/Database.Tests.ps1` — add `scan_checkpoint` to schema mock and migration checks

---

