#requires -Version 7.4

Set-StrictMode -Version Latest

$privateScripts = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File | Sort-Object Name
foreach ($script in $privateScripts) {
    . $script.FullName
}

$publicScripts = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File | Sort-Object Name
foreach ($script in $publicScripts) {
    . $script.FullName
}

Export-ModuleMember -Function @(
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
