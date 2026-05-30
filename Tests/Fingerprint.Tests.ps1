Describe 'Get-TrackstashFingerprint' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../trackstash-scan.psd1" -Force
    }

    It 'returns fingerprint and duration from psMusicTagger cmdlets' {
        InModuleScope trackstash-scan {
            if (-not (Get-Command -Name Get-AudioFingerprint -ErrorAction SilentlyContinue)) {
                function Get-AudioFingerprint {
                    param([string]$Path)
                    throw 'Get-AudioFingerprint stub should be mocked in tests.'
                }
            }
            if (-not (Get-Command -Name Get-AudioDuration -ErrorAction SilentlyContinue)) {
                function Get-AudioDuration {
                    param([string]$Path)
                    throw 'Get-AudioDuration stub should be mocked in tests.'
                }
            }

            Mock -CommandName Get-AudioFingerprint -MockWith {
                [pscustomobject]@{
                    Fingerprint = 'raw-fingerprint'
                }
            }

            Mock -CommandName Get-AudioDuration -MockWith { 123.45 }
            Mock -CommandName Get-Command -MockWith { $null } -ParameterFilter { $Name -eq 'Get-AcoustIdSubmissionHash' }

            $result = Get-TrackstashFingerprint -Path '/tmp/fake.mp3'

            $result.FingerprintRaw | Should -Be 'raw-fingerprint'
            $result.DurationSeconds | Should -Be 123.45
            $result.AcoustIdSubmissionHash | Should -Be $null
        }
    }
}
