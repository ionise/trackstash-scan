<#
.SYNOPSIS
Writes timestamped scan log messages.

.DESCRIPTION
Formats log entries with UTC timestamp and level, then writes to Verbose,
Warning, or Error streams based on log level.

.PARAMETER Level
Log severity level: Info, Warning, or Error.

.PARAMETER Message
Log message text.

.EXAMPLE
Write-TrackstashLog -Level Warning -Message 'Unsupported file skipped.'
#>
function Write-TrackstashLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString('o')
    $formatted = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'Info' { Write-Verbose $formatted }
        'Warning' { Write-Warning $formatted }
        # Force non-terminating behavior so per-file scan failures do not abort whole scans.
        'Error' { Write-Error $formatted -ErrorAction Continue }
    }
}
