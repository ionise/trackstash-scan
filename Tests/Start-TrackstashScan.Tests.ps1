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
                [pscustomobject]@{ Artist = $null; Title = $null; Album = $null; Label = $null; Release = $null; TrackNumber = $null; DiscNumber = $null; BPM = $null; Key = $null; Genre = $null; Year = $null; ArtworkHash = $null }
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
}
