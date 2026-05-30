Describe 'Get-TrackstashFileHash' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../trackstash-scan.psd1" -Force
    }

    It 'returns a SHA256 hash for an existing file' {
        $tempFile = Join-Path $TestDrive 'hash-test.txt'
        Set-Content -Path $tempFile -Value 'trackstash'

        $hash = Get-TrackstashFileHash -Path $tempFile

        $hash | Should -Not -BeNullOrEmpty
        $hash.Length | Should -Be 64
    }
}
