<#
.SYNOPSIS
Computes fingerprint, AcoustID submission hash, and duration for a media file.

.DESCRIPTION
Calls Get-AcoustIDFingerprint from PsAcoustId. Returns raw fingerprint output,
duration, and AcoustID submission hash when available. If PsAcoustId cannot
open FLAC or MP3 files due to missing optional readers, the function falls
back to ffmpeg-based conversion to temporary WAV and retries fingerprinting.

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

    function Invoke-TrackstashAcoustId {
        param(
            [Parameter(Mandatory)]
            [string]$InputPath
        )

        $result = Get-AcoustIDFingerprint -Path $InputPath -ErrorAction Stop
        if ($result -is [System.Array]) {
            return ($result | Select-Object -First 1)
        }

        return $result
    }

    $rawFingerprintResult = $null
    try {
        $rawFingerprintResult = Invoke-TrackstashAcoustId -InputPath $Path
    }
    catch {
        $exceptionMessage = $_.Exception.Message
        $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
        $readerMissing = $exceptionMessage -match 'FLAC reader not available|Failed to open FLAC file|MP3 reader not available|Failed to open MP3 file'

        if ($readerMissing -and $extension -in @('.flac', '.mp3')) {
            $ffmpeg = Get-Command -Name 'ffmpeg' -ErrorAction SilentlyContinue
            if (-not $ffmpeg) {
                throw "PsAcoustId could not open '$extension' input and ffmpeg is not available for fallback conversion. Install ffmpeg or use WAV/AIFF. Original error: $exceptionMessage"
            }

            $tempWavPath = Join-Path ([System.IO.Path]::GetTempPath()) ("trackstash-scan-" + [guid]::NewGuid().ToString('N') + '.wav')
            try {
                & $ffmpeg.Source -hide_banner -loglevel error -y -i $Path -ac 2 -ar 44100 -sample_fmt s16 $tempWavPath
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tempWavPath)) {
                    throw "ffmpeg conversion failed for '$Path'."
                }

                $rawFingerprintResult = Invoke-TrackstashAcoustId -InputPath $tempWavPath
            }
            finally {
                if (Test-Path -LiteralPath $tempWavPath) {
                    Remove-Item -LiteralPath $tempWavPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            throw
        }
    }

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

    $durationSeconds = $null
    if ($null -ne $rawFingerprintResult.PSObject.Properties['Duration']) {
        $durationSeconds = $rawFingerprintResult.Duration
    }
    elseif ($null -ne $rawFingerprintResult.PSObject.Properties['DurationSeconds']) {
        $durationSeconds = $rawFingerprintResult.DurationSeconds
    }

    $acoustIdSubmissionHash = $null
    if ($null -ne $rawFingerprintResult.PSObject.Properties['AcoustIdSubmissionHash']) {
        $acoustIdSubmissionHash = $rawFingerprintResult.AcoustIdSubmissionHash
    }
    elseif ($null -ne $rawFingerprintResult.PSObject.Properties['SubmissionHash']) {
        $acoustIdSubmissionHash = $rawFingerprintResult.SubmissionHash
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
