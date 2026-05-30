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
}
