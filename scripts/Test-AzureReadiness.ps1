#requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('Local','Fixture','AzureReadOnly')][string]$Mode='Local',
    [switch]$LocalOnly,
    [string]$FixturePath,
    [string]$SubscriptionId,
    [string]$Location='westeurope',
    [ValidateSet('foundation','secure','applications','hybrid')][string]$Stage='foundation'
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Infrastructure.Readiness.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Infrastructure.Common.psm1') -Force
if ($LocalOnly -and $Mode -ne 'Local') { throw '-LocalOnly cannot be combined with cloud or fixture modes.' }
if ($FixturePath -and $Mode -ne 'Fixture') { throw 'Synthetic data requires -Mode Fixture.' }
$versions=@{}; $cloud=$null; $source='local'
if ($Mode -eq 'Fixture') {
    if (-not $FixturePath) { throw 'Fixture mode requires -FixturePath; no real fallback is permitted.' }
    $fixture=Get-Content -LiteralPath $FixturePath -Raw | ConvertFrom-Json -AsHashtable
    if ($fixture.evidence_kind -ne 'synthetic') { throw 'Readiness fixture must be labelled synthetic.' }
    $versions=$fixture.tools; $cloud=$fixture.cloud; $source='synthetic'
} else {
    $versions.pwsh=$PSVersionTable.PSVersion.ToString()
    foreach ($name in @('terraform','az','git','code')) {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { continue }
        $argsList=if ($name -eq 'terraform') {@('version','-json')} elseif ($name -eq 'az') {@('version','-o','json')} else {@('--version')}
        $result=Invoke-InfrastructureNative -Command $name -Arguments $argsList -TimeoutSeconds 30
        if ($result.exit_code -ne 0) { continue }
        try {
            if ($name -eq 'terraform') { $versions[$name]=($result.output | ConvertFrom-Json).terraform_version }
            elseif ($name -eq 'az') { $versions[$name]=($result.output | ConvertFrom-Json).'azure-cli' }
            elseif ($result.output -match '(\d+\.\d+\.\d+)') { $versions[$name]=$Matches[1] }
        } catch { $versions[$name]='invalid' }
    }
    if ($Mode -eq 'AzureReadOnly') {
        $subscriptionGuid=[guid]::Empty
        if (-not [guid]::TryParse($SubscriptionId,[ref]$subscriptionGuid)) { throw 'AzureReadOnly requires an explicit subscription UUID. The script never signs in or chooses an account.' }
        $source='azure-read-only'
        function AzJson([string[]]$Arguments) {
            $result=Invoke-InfrastructureNative -Command az -Arguments ($Arguments+@('--subscription',$SubscriptionId,'-o','json','--only-show-errors')) -TimeoutSeconds 45
            if ($result.exit_code -ne 0) { throw 'Azure query failed.' }
            $result.output | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        try {
            $cloud=@{account=(AzJson @('account','show'));providers=@{}}
            $required=(Test-InfrastructureReadiness -Tools $versions -Stage $Stage).requirements.providers
            foreach ($provider in $required) {
                $details=AzJson @('provider','show','--namespace',$provider); $cloud.providers[$provider]=$details.registrationState
                if ($provider -eq 'Microsoft.Network') { $cloud.network_types=$details.resourceTypes }
            }
            if ($Stage -in @('applications','hybrid')) {
                $cloud.vm_skus=@(AzJson @('vm','list-skus','--location',$Location,'--size','Standard_B2s','--all'))
                $cloud.usage=@(AzJson @('vm','list-usage','--location',$Location))
            }
        } catch { $cloud=@{_error='readiness collection failed'} }
    }
}
$report=Test-InfrastructureReadiness -Tools $versions -Cloud $cloud -Stage $Stage -SubscriptionId $SubscriptionId -Location $Location -Source $source
$report | ConvertTo-Json -Depth 20
if ($report.summary.fail -gt 0) { throw 'Readiness has blocked checks. Inspect the JSON report; Azure runtime remains unverified.' }
