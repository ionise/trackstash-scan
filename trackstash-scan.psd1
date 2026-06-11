@{
    RootModule        = 'trackstash-scan.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '8cd7bcbf-4df6-4d96-b7de-6e3db5e1b913'
    Author            = 'David Alderman'
    CompanyName       = 'David Alderman'
    Copyright         = '(c) David Alderman. All rights reserved.'
    Description       = 'Filesystem audio scanner that extracts metadata and fingerprints via psMusicTagger and persists to SQLite.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        'psMusicTagger',
        'PsAcoustId'
    )

    FunctionsToExport = @(
        'Start-TrackstashScan',
        'Get-TrackstashScanCheckpointStatus',
        'Get-TrackstashRecord',
        'Get-TrackstashLibrary',
        'Get-TrackstashMediaFiles',
        'Get-TrackstashFileHash',
        'Get-TrackstashMetadata',
        'Get-TrackstashFingerprint',
        'Save-TrackstashRecord'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags       = @('trackstash', 'audio', 'scanner', 'sqlite', 'psMusicTagger')
            ProjectUri = 'https://github.com/ionise/trackstash-scan'
        }
    }
}
