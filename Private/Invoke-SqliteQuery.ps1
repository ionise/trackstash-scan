<#
.SYNOPSIS
Executes a parameterized SQLite query using Microsoft.Data.Sqlite.

.DESCRIPTION
Loads Microsoft.Data.Sqlite, opens a connection to the provided database, binds
query parameters, and executes as NonQuery, Scalar, or Reader.

.PARAMETER DatabasePath
Path to the SQLite database file.

.PARAMETER Query
SQL statement text to execute.

.PARAMETER Parameters
Optional hashtable of SQL parameters.

.PARAMETER QueryType
Execution mode: NonQuery, Scalar, or Reader.

.OUTPUTS
Depends on QueryType: integer rows affected, scalar value, or object array.

.EXAMPLE
Invoke-SqliteQuery -DatabasePath './trackstash-scan.db' -Query 'SELECT 1' -QueryType Scalar
#>
function Invoke-SqliteQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [Parameter(Mandatory)]
        [string]$Query,

        [Parameter()]
        [hashtable]$Parameters,

        [Parameter()]
        [ValidateSet('NonQuery', 'Scalar', 'Reader')]
        [string]$QueryType = 'NonQuery'
    )

    $sqliteLoaded = $false
    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
    $localDllCandidates = @(
        (Join-Path $moduleRoot 'Dependencies/Microsoft.Data.Sqlite/Microsoft.Data.Sqlite.dll')
    )

    foreach ($dllPath in $localDllCandidates) {
        if (Test-Path -LiteralPath $dllPath) {
            try {
                Add-Type -Path $dllPath -ErrorAction Stop
                $sqliteLoaded = $true
                break
            }
            catch {
                continue
            }
        }
    }

    if (-not $sqliteLoaded) {
        try {
            Add-Type -AssemblyName Microsoft.Data.Sqlite -ErrorAction Stop
            $sqliteLoaded = $true
        }
        catch {
            throw "Microsoft.Data.Sqlite assembly is required but could not be loaded. Run scripts/Install-TrackstashScanDependencies.ps1 or install the package manually. Error: $($_.Exception.Message)"
        }
    }

    $connectionStringBuilder = [Microsoft.Data.Sqlite.SqliteConnectionStringBuilder]::new()
    $connectionStringBuilder.DataSource = $DatabasePath

    $connection = [Microsoft.Data.Sqlite.SqliteConnection]::new($connectionStringBuilder.ConnectionString)
    $connection.Open()

    try {
        $command = $connection.CreateCommand()
        $command.CommandText = $Query

        if ($Parameters) {
            foreach ($key in $Parameters.Keys) {
                $paramName = if ($key.StartsWith('@')) { $key } else { "@$key" }
                $value = $Parameters[$key]
                if ($null -eq $value) {
                    $value = [System.DBNull]::Value
                }
                [void]$command.Parameters.AddWithValue($paramName, $value)
            }
        }

        switch ($QueryType) {
            'NonQuery' {
                return $command.ExecuteNonQuery()
            }
            'Scalar' {
                $scalar = $command.ExecuteScalar()
                if ($scalar -is [System.DBNull]) {
                    return $null
                }
                return $scalar
            }
            'Reader' {
                $reader = $command.ExecuteReader()
                try {
                    $rows = @()
                    while ($reader.Read()) {
                        $row = [ordered]@{}
                        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                            $value = $reader.GetValue($i)
                            if ($value -is [System.DBNull]) {
                                $value = $null
                            }
                            $row[$reader.GetName($i)] = $value
                        }
                        $rows += [pscustomobject]$row
                    }
                    return $rows
                }
                finally {
                    $reader.Dispose()
                }
            }
        }
    }
    finally {
        $connection.Dispose()
    }
}
