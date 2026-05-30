Describe 'Get-TrackstashMetadata' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../trackstash-scan.psd1" -Force
    }

    It 'normalizes metadata fields and keeps missing values as null' {
        InModuleScope trackstash-scan {
            if (-not (Get-Command -Name Get-MusicMetadata -ErrorAction SilentlyContinue)) {
                function Get-MusicMetadata {
                    param([string]$Path)
                    throw 'Get-MusicMetadata stub should be mocked in tests.'
                }
            }

            Mock -CommandName Get-MusicMetadata -MockWith {
                [pscustomobject]@{
                    Artist      = 'Artist A'
                    Title       = 'Track A'
                    Album       = $null
                    Label       = $null
                    Release     = 'Release A'
                    TrackNumber = ''
                    DiscNumber  = ''
                    BPM         = ''
                    Key         = 'Gm'
                    Genre       = $null
                    Year        = ''
                }
            }

            $result = Get-TrackstashMetadata -Path '/tmp/fake.mp3'

            $result.Artist | Should -Be 'Artist A'
            $result.TrackNumber | Should -Be $null
            $result.DiscNumber | Should -Be $null
            $result.BPM | Should -Be $null
            $result.Year | Should -Be $null
            $result.ArtworkHash | Should -Be $null
        }
    }

    It 'falls back to Get-TrackMetadata when Get-MusicMetadata is unavailable' {
        InModuleScope trackstash-scan {
            if (-not (Get-Command -Name Get-TrackMetadata -ErrorAction SilentlyContinue)) {
                function Get-TrackMetadata {
                    param([string]$FilePath)
                    throw 'Get-TrackMetadata stub should be mocked in tests.'
                }
            }

            Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'Get-MusicMetadata' } -MockWith { $null }
            Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'Get-TrackMetadata' } -MockWith {
                [pscustomobject]@{ Name = 'Get-TrackMetadata' }
            }

            Mock -CommandName Get-TrackMetadata -MockWith {
                [pscustomobject]@{
                    Artist      = 'Artist B'
                    Title       = 'Track B'
                    Album       = 'Album B'
                    Label       = 'Label B'
                    Release     = 'Release B'
                    TrackNumber = 1
                    DiscNumber  = 1
                    BPM         = 128
                    Key         = 'Am'
                    Genre       = 'House'
                    Year        = 2024
                }
            }

            $result = Get-TrackstashMetadata -Path '/tmp/fallback.flac'

            $result.Artist | Should -Be 'Artist B'
            $result.Title | Should -Be 'Track B'
            $result.Album | Should -Be 'Album B'
            Should -Invoke Get-TrackMetadata -Times 1
        }
    }

    It 'maps Label from Publisher when Label is not present' {
        InModuleScope trackstash-scan {
            if (-not (Get-Command -Name Get-MusicMetadata -ErrorAction SilentlyContinue)) {
                function Get-MusicMetadata {
                    param([string]$Path)
                    throw 'Get-MusicMetadata stub should be mocked in tests.'
                }
            }

            Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'Get-MusicMetadata' } -MockWith {
                [pscustomobject]@{ Name = 'Get-MusicMetadata' }
            }

            Mock -CommandName Get-MusicMetadata -MockWith {
                [pscustomobject]@{
                    Artist    = 'Artist C'
                    Title     = 'Track C'
                    Publisher = 'Zero Tolerance Recordings'
                }
            }

            $result = Get-TrackstashMetadata -Path '/tmp/publisher.flac'

            $result.Label | Should -Be 'Zero Tolerance Recordings'
            $result.Album | Should -Be $null
            $result.Year | Should -Be $null
        }
    }
}
