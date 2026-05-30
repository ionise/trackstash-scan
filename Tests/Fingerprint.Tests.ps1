Describe 'Get-TrackstashFingerprint' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../trackstash-scan.psd1" -Force
    }

    It 'returns fingerprint and duration from PsAcoustId cmdlet output' {
        InModuleScope trackstash-scan {
            if (-not (Get-Command -Name Get-AcoustIDFingerprint -ErrorAction SilentlyContinue)) {
                function Get-AcoustIDFingerprint {
                    param([string]$Path)
                    throw 'Get-AcoustIDFingerprint stub should be mocked in tests.'
                }
            }

            Mock -CommandName Get-AcoustIDFingerprint -MockWith {
                [pscustomobject]@{
                    Fingerprint = 'raw-fingerprint'
                    Duration    = 123.45
                }
            }

            Mock -CommandName Get-Command -MockWith { $null } -ParameterFilter { $Name -eq 'Get-AcoustIdSubmissionHash' }

            $result = Get-TrackstashFingerprint -Path '/tmp/fake.mp3'

            $result.FingerprintRaw | Should -Be 'raw-fingerprint'
            $result.DurationSeconds | Should -Be 123.45
            $result.AcoustIdSubmissionHash | Should -Be $null
        }
    }
}
