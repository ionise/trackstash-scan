Describe 'Write-TrackstashLog' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../trackstash-scan.psd1" -Force
    }

    It 'does not throw for error-level logs when ErrorActionPreference is Stop' {
        InModuleScope trackstash-scan {
            $previousPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'
                { Write-TrackstashLog -Level Error -Message 'test error log' } | Should -Not -Throw
            }
            finally {
                $ErrorActionPreference = $previousPreference
            }
        }
    }
}
