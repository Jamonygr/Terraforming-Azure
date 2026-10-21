[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
$records = @(Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
if ($records.Count -ne 2) { throw 'Provide the Fired and Resolved observations for one synthetic alert.' }
$first = $records[0].properties.essentials
$second = $records[1].properties.essentials
if ($first.monitorCondition -cne 'Fired' -or $second.monitorCondition -cne 'Resolved') { throw 'Expected Fired followed by Resolved.' }
if (-not $first.alertRule -or $first.alertRule -cne $second.alertRule) { throw 'Both observations must identify the same alert rule.' }
if ([DateTimeOffset]::Parse($second.lastModifiedDateTime) -le [DateTimeOffset]::Parse($first.lastModifiedDateTime)) { throw 'Resolution must follow firing.' }
[pscustomobject]@{ evidence_mode='saved_response'; rule=$first.alertRule; fired_then_resolved=$true }
