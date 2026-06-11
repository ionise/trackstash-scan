#requires -Version 7.4

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string[]]$Root,

    [Parameter()]
    [string]$DatabasePath = './trackstash-scan.db',

    [Parameter()]
    [switch]$Recurse,

    [Parameter()]
    [switch]$ForceRescan,

    [Parameter()]
    [switch]$ShowProgress,

    [Parameter()]
    [switch]$Resume
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\trackstash-scan.psd1'
Import-Module -Name $modulePath -Force

$scanParams = @{
    Root         = $Root
    DatabasePath = $DatabasePath
    Recurse      = $Recurse
    ForceRescan  = $ForceRescan
    ShowProgress = $ShowProgress
    Resume       = $Resume
    Verbose      = $VerbosePreference -ne 'SilentlyContinue'
    WhatIf       = $WhatIfPreference
}

$result = Start-TrackstashScan @scanParams
$result
