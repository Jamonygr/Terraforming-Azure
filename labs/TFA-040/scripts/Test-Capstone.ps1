#requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('Fixture','AzureReadOnly')][string]$Mode='Fixture',
    [string]$FixturePath,
    [string]$OutputPath,
    [switch]$SkipPublicIngress
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Capstone.Evidence.psm1') -Force
if ($Mode -eq 'Fixture') {
    if (-not $FixturePath) { throw 'Default mode is offline. Supply -FixturePath with a synthetic snapshot, or explicitly select -Mode AzureReadOnly.' }
    $snapshot=Get-Content -LiteralPath $FixturePath -Raw | ConvertFrom-Json -AsHashtable
    if ($snapshot.evidence_kind -ne 'synthetic') { throw 'Fixture files must be labelled synthetic; they cannot certify runtime behavior.' }
} else {
    if ($FixturePath) { throw 'Do not mix synthetic snapshots with AzureReadOnly mode.' }
    $snapshot=& (Join-Path $PSScriptRoot 'Get-CapstoneSnapshot.ps1') -AzureReadOnly -SkipPublicIngress:$SkipPublicIngress
}
$report=Test-CapstoneSnapshot -Snapshot $snapshot
$json=$report | ConvertTo-Json -Depth 20
if ($OutputPath) { $json | Set-Content -LiteralPath $OutputPath -Encoding utf8 }
$json
if ($report.summary.fail -gt 0) { throw 'One or more evidence checks failed. Inspect the status report; raw service responses are suppressed.' }
