Describe 'Start-TrackstashScan' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../trackstash-scan.psd1" -Force
    }

    It 'continues on file errors and returns summary' {
        InModuleScope trackstash-scan {
            Mock -CommandName Initialize-TrackstashDatabase -MockWith { '/tmp/test.db' }
            Mock -CommandName Get-TrackstashMediaFiles -MockWith {
                @(
                    [pscustomobject]@{ Path = '/tmp/a.mp3'; SizeBytes = 100; LastModifiedUtc = [datetime]::UtcNow; Format = 'mp3' },
                    [pscustomobject]@{ Path = '/tmp/b.mp3'; SizeBytes = 200; LastModifiedUtc = [datetime]::UtcNow; Format = 'mp3' }
                )
            }

            Mock -CommandName Get-TrackstashFileHash -MockWith {
                if ($Path -eq '/tmp/a.mp3') { throw 'broken file' }
                return 'abc123'
            }

            Mock -CommandName Invoke-SqliteQuery -MockWith { $null }
            Mock -CommandName Get-TrackstashFingerprint -MockWith {
                [pscustomobject]@{ FingerprintRaw = 'f'; AcoustIdSubmissionHash = 'h'; DurationSeconds = 10.0 }
            }
            Mock -CommandName Get-TrackstashMetadata -MockWith {
                [pscustomobject]@{ Artist = $null; Title = $null; Album = $null; Label = $null; Release = $null; Isrc = $null; Barcode = $null; CatalogNumber = $null; TrackNumber = $null; DiscNumber = $null; BPM = $null; Key = $null; Genre = $null; Year = $null; ArtworkHash = $null }
            }
            Mock -CommandName Save-TrackstashRecord -MockWith { 1 }
            Mock -CommandName Write-TrackstashLog

            $result = Start-TrackstashScan -Root '/tmp' -Recurse

            $result.TotalFiles | Should -Be 2
            $result.Errors | Should -Be 1
            $result.Processed | Should -Be 1
            Should -Invoke Write-TrackstashLog -Times 1
        }
    }

    It 'skips checkpointed files when resume is enabled' {
        InModuleScope trackstash-scan {
            Mock -CommandName Initialize-TrackstashDatabase -MockWith { '/tmp/test.db' }
            Mock -CommandName Get-TrackstashMediaFiles -MockWith {
                @(
                    [pscustomobject]@{ Path = '/tmp/a.mp3'; SizeBytes = 100; LastModifiedUtc = [datetime]::UtcNow; Format = 'mp3' },
                    [pscustomobject]@{ Path = '/tmp/b.mp3'; SizeBytes = 200; LastModifiedUtc = [datetime]::UtcNow; Format = 'mp3' }
                )
            }

            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $Query -like 'SELECT 1 FROM scan_checkpoint*' -and $Parameters['path'] -eq '/tmp/a.mp3' } -MockWith { 1 }
            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $Query -like 'SELECT 1 FROM scan_checkpoint*' -and $Parameters['path'] -eq '/tmp/b.mp3' } -MockWith { $null }
            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $Query -eq 'SELECT media_file_id FROM media_file WHERE content_hash = @content_hash;' } -MockWith { $null }
            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $Query -like 'INSERT INTO scan_checkpoint*' } -MockWith { 1 }
            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $Query -like 'DELETE FROM scan_checkpoint WHERE root = @root;' } -MockWith { 1 }

            Mock -CommandName Get-TrackstashFileHash -MockWith { 'hash-b' }
            Mock -CommandName Get-TrackstashFingerprint -MockWith {
                [pscustomobject]@{ FingerprintRaw = 'f'; AcoustIdSubmissionHash = 'h'; DurationSeconds = 10.0 }
            }
            Mock -CommandName Get-TrackstashMetadata -MockWith {
                [pscustomobject]@{ Artist = $null; Title = $null; Album = $null; Label = $null; Release = $null; Isrc = $null; Barcode = $null; CatalogNumber = $null; TrackNumber = $null; DiscNumber = $null; BPM = $null; Key = $null; Genre = $null; Year = $null; ArtworkHash = $null }
            }
            Mock -CommandName Save-TrackstashRecord -MockWith { 1 }

            $result = Start-TrackstashScan -Root '/tmp' -Recurse -Resume

            $result.TotalFiles | Should -Be 2
            $result.Skipped | Should -Be 1
            $result.Processed | Should -Be 1
            Should -Invoke Get-TrackstashFileHash -Times 1
        }
    }

    It 'writes progress when show progress is enabled' {
        InModuleScope trackstash-scan {
            Mock -CommandName Initialize-TrackstashDatabase -MockWith { '/tmp/test.db' }
            Mock -CommandName Get-TrackstashMediaFiles -MockWith {
                @([pscustomobject]@{ Path = '/tmp/a.mp3'; SizeBytes = 100; LastModifiedUtc = [datetime]::UtcNow; Format = 'mp3' })
            }

            Mock -CommandName Get-TrackstashFileHash -MockWith { 'hash-a' }
            Mock -CommandName Invoke-SqliteQuery -MockWith { $null }
            Mock -CommandName Get-TrackstashFingerprint -MockWith {
                [pscustomobject]@{ FingerprintRaw = 'f'; AcoustIdSubmissionHash = 'h'; DurationSeconds = 10.0 }
            }
            Mock -CommandName Get-TrackstashMetadata -MockWith {
                [pscustomobject]@{ Artist = $null; Title = $null; Album = $null; Label = $null; Release = $null; Isrc = $null; Barcode = $null; CatalogNumber = $null; TrackNumber = $null; DiscNumber = $null; BPM = $null; Key = $null; Genre = $null; Year = $null; ArtworkHash = $null }
            }
            Mock -CommandName Save-TrackstashRecord -MockWith { 1 }
            Mock -CommandName Write-Progress

            [void](Start-TrackstashScan -Root '/tmp' -Recurse -ShowProgress)

            Should -Invoke Write-Progress -Times 2
        }
    }
}
