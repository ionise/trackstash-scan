<#
.SYNOPSIS
Computes fingerprint, AcoustID submission hash, and duration for a media file.

.DESCRIPTION
Calls Get-AudioFingerprint and Get-AudioDuration from psMusicTagger. Returns raw
fingerprint output plus AcoustID submission hash when available.

.PARAMETER Path
Path to the media file.

.OUTPUTS
PSCustomObject containing FingerprintRaw, AcoustIdSubmissionHash, and DurationSeconds.

.EXAMPLE
Get-TrackstashFingerprint -Path '/music/track01.ogg'
#>
function Get-TrackstashFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $rawFingerprintResult = Get-AudioFingerprint -Path $Path -ErrorAction Stop

    $fingerprint = $null
    if ($null -ne $rawFingerprintResult.PSObject.Properties['Fingerprint']) {
        $fingerprint = $rawFingerprintResult.Fingerprint
    }
    elseif ($rawFingerprintResult -is [string]) {
        $fingerprint = $rawFingerprintResult
    }
    else {
        $fingerprint = $rawFingerprintResult | ConvertTo-Json -Compress
    }

    $durationSeconds = Get-AudioDuration -Path $Path -ErrorAction Stop

    $acoustIdSubmissionHash = $null
    if ($null -ne $rawFingerprintResult.PSObject.Properties['AcoustIdSubmissionHash']) {
        $acoustIdSubmissionHash = $rawFingerprintResult.AcoustIdSubmissionHash
    }
    elseif (Get-Command -Name 'Get-AcoustIdSubmissionHash' -ErrorAction SilentlyContinue) {
        $acoustIdSubmissionHash = Get-AcoustIdSubmissionHash -Fingerprint $fingerprint -Duration $durationSeconds
    }

    return [pscustomobject]@{
        FingerprintRaw       = $fingerprint
        AcoustIdSubmissionHash = $acoustIdSubmissionHash
        DurationSeconds      = $durationSeconds
    }
}
