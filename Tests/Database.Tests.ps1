Describe 'Database helpers' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../trackstash-scan.psd1" -Force
    }

    It 'creates database schema successfully' {
        InModuleScope trackstash-scan {
            $dbPath = Join-Path $TestDrive 'trackstash.db'

            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $QueryType -eq 'Reader' } -MockWith {
                @(
                    [pscustomobject]@{ name = 'metadata_id' }
                    [pscustomobject]@{ name = 'media_file_id' }
                    [pscustomobject]@{ name = 'artist' }
                    [pscustomobject]@{ name = 'title' }
                    [pscustomobject]@{ name = 'album' }
                    [pscustomobject]@{ name = 'label' }
                    [pscustomobject]@{ name = 'release' }
                    [pscustomobject]@{ name = 'isrc' }
                    [pscustomobject]@{ name = 'barcode' }
                    [pscustomobject]@{ name = 'catalog_number' }
                    [pscustomobject]@{ name = 'track_number' }
                    [pscustomobject]@{ name = 'disc_number' }
                    [pscustomobject]@{ name = 'bpm' }
                    [pscustomobject]@{ name = 'musical_key' }
                    [pscustomobject]@{ name = 'genre' }
                    [pscustomobject]@{ name = 'year' }
                    [pscustomobject]@{ name = 'artwork_hash' }
                )
            }
            Mock -CommandName Invoke-SqliteQuery -ParameterFilter { $QueryType -ne 'Reader' } -MockWith { 1 }

            $resolved = Initialize-TrackstashDatabase -DatabasePath $dbPath

            $resolved | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-SqliteQuery -Times 2
            Should -Invoke Invoke-SqliteQuery -Times 1 -ParameterFilter {
                $QueryType -eq 'NonQuery' -and $Query -match 'CREATE TABLE IF NOT EXISTS scan_checkpoint'
            }
        }
    }
}
