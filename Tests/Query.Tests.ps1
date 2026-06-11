Describe 'Get-TrackstashRecord' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../trackstash-scan.psd1" -Force
    }

    It 'builds contains filters and free-text search query' {
        InModuleScope trackstash-scan {
            $dbPath = Join-Path $TestDrive 'trackstash.db'
            New-Item -ItemType File -Path $dbPath -Force | Out-Null

            Mock -CommandName Invoke-SqliteQuery -MockWith {
                @(
                    [pscustomobject]@{ media_file_id = 1; artist = 'Calibre'; title = 'Even If' }
                )
            }

            $result = Get-TrackstashRecord -DatabasePath $dbPath -Artist 'Calibre' -Genre 'Drum' -Search 'Hospital' -Limit 25

            $result.Count | Should -Be 1
            $result[0].artist | Should -Be 'Calibre'

            Should -Invoke Invoke-SqliteQuery -Times 1 -ParameterFilter {
                $QueryType -eq 'Reader' -and
                $Query -match 'md.artist LIKE @artist' -and
                $Query -match 'md.genre LIKE @genre' -and
                $Query -match 'md.catalog_number LIKE @search' -and
                $Parameters['artist'] -eq '%Calibre%' -and
                $Parameters['genre'] -eq '%Drum%' -and
                $Parameters['search'] -eq '%Hospital%' -and
                $Parameters['limit'] -eq 25
            }
        }
    }

    It 'uses exact matching and sortable fields' {
        InModuleScope trackstash-scan {
            $dbPath = Join-Path $TestDrive 'trackstash.db'
            New-Item -ItemType File -Path $dbPath -Force | Out-Null

            Mock -CommandName Invoke-SqliteQuery -MockWith { @() }

            [void](Get-TrackstashRecord -DatabasePath $dbPath -Isrc 'USABC9911122' -ExactMatch -OrderBy artist -Descending)

            Should -Invoke Invoke-SqliteQuery -Times 1 -ParameterFilter {
                $QueryType -eq 'Reader' -and
                $Query -match 'md.isrc = @isrc' -and
                $Query -match 'ORDER BY md.artist DESC' -and
                $Parameters['isrc'] -eq 'USABC9911122'
            }
        }
    }
}
