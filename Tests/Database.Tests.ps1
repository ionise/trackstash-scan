Describe 'Database helpers' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../trackstash-scan.psd1" -Force
    }

    It 'creates database schema successfully' {
        InModuleScope trackstash-scan {
            $dbPath = Join-Path $TestDrive 'trackstash.db'

            Mock -CommandName Invoke-SqliteQuery -MockWith { 1 }

            $resolved = Initialize-TrackstashDatabase -DatabasePath $dbPath

            $resolved | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-SqliteQuery -Times 1
        }
    }
}
