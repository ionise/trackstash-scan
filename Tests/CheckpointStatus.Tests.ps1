Describe 'Get-TrackstashScanCheckpointStatus' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../trackstash-scan.psd1" -Force
    }

    It 'returns summary and per-root checkpoint counts' {
        InModuleScope trackstash-scan {
            Mock -CommandName Initialize-TrackstashDatabase -MockWith { '/tmp/test.db' }

            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $Query -match 'COUNT\(\*\) AS total_checkpoints' } -MockWith {
                @([pscustomobject]@{
                    total_checkpoints     = 3
                    roots_with_checkpoints = 1
                    oldest_checkpoint_utc = '2026-06-01T00:00:00.0000000Z'
                    newest_checkpoint_utc = '2026-06-01T00:10:00.0000000Z'
                })
            }

            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $Query -match 'GROUP BY root' } -MockWith {
                @([pscustomobject]@{
                    root                  = '/Volumes/music/Backup'
                    checkpoint_count      = 3
                    oldest_checkpoint_utc = '2026-06-01T00:00:00.0000000Z'
                    newest_checkpoint_utc = '2026-06-01T00:10:00.0000000Z'
                })
            }

            $result = Get-TrackstashScanCheckpointStatus -DatabasePath '/tmp/test.db'

            $result.TotalCheckpoints | Should -Be 3
            $result.RootsWithCheckpoints | Should -Be 1
            $result.ByRoot.Count | Should -Be 1
            $result.RecentPaths.Count | Should -Be 0
        }
    }

    It 'applies root filter and returns recent paths when requested' {
        InModuleScope trackstash-scan {
            Mock -CommandName Initialize-TrackstashDatabase -MockWith { '/tmp/test.db' }

            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $Query -match 'COUNT\(\*\) AS total_checkpoints' } -MockWith {
                @([pscustomobject]@{
                    total_checkpoints     = 1
                    roots_with_checkpoints = 1
                    oldest_checkpoint_utc = '2026-06-01T00:10:00.0000000Z'
                    newest_checkpoint_utc = '2026-06-01T00:10:00.0000000Z'
                })
            }

            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $Query -match 'GROUP BY root' } -MockWith {
                @([pscustomobject]@{
                    root                  = '/Volumes/music/Backup'
                    checkpoint_count      = 1
                    oldest_checkpoint_utc = '2026-06-01T00:10:00.0000000Z'
                    newest_checkpoint_utc = '2026-06-01T00:10:00.0000000Z'
                })
            }

            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $Query -match 'ORDER BY checkpointed_utc DESC' } -MockWith {
                @([pscustomobject]@{
                    root            = '/Volumes/music/Backup'
                    path            = '/Volumes/music/Backup/track.flac'
                    content_hash    = 'abc123'
                    checkpointed_utc = '2026-06-01T00:10:00.0000000Z'
                })
            }

            $result = Get-TrackstashScanCheckpointStatus -DatabasePath '/tmp/test.db' -Root '/Volumes/music/Backup' -IncludeRecentPaths -RecentPathLimit 10

            $result.TotalCheckpoints | Should -Be 1
            $result.RecentPaths.Count | Should -Be 1
            Should -Invoke Invoke-SqliteQuery -Times 1 -ParameterFilter {
                $Query -match 'ORDER BY checkpointed_utc DESC' -and
                $Parameters['recent_limit'] -eq 10 -and
                $Parameters.ContainsKey('root_0')
            }
        }
    }
}
