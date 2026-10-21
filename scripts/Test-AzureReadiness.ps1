[CmdletBinding()]
param([switch]$LocalOnly, [string]$SubscriptionId, [string]$Location = 'westeurope')
$ErrorActionPreference = 'Stop'
$commands = @('pwsh','terraform','az','git','code')
$missing = @()
foreach ($command in $commands) {
  $found = Get-Command $command -ErrorAction SilentlyContinue
  if ($found) { Write-Output "PASS tool $command" } else { $missing += $command; Write-Warning "Missing: $command" }
}
if ($missing.Count) { throw "Install the missing tools from TFA-002: $($missing -join ', ')" }
terraform version
if ($LASTEXITCODE -ne 0) { throw 'Terraform toolchain failed.' }
if ($LocalOnly) { return }
if (-not $SubscriptionId) { throw 'Pass an explicit -SubscriptionId; this script never chooses one for you.' }
$accountJson = az account show --subscription $SubscriptionId --output json --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Azure account lookup failed. Run az login first.' }
$account = $accountJson | ConvertFrom-Json
if ($account.id -ne $SubscriptionId -or $account.state -ne 'Enabled') { throw 'Subscription identity or status did not match.' }
Write-Output "PASS explicit enabled subscription and tenant. Region to verify: $Location"
$providers = @('Microsoft.Resources','Microsoft.Network','Microsoft.Compute','Microsoft.Storage','Microsoft.KeyVault','Microsoft.OperationalInsights','Microsoft.Insights','Microsoft.ManagedIdentity')
foreach ($provider in $providers) {
  $state = az provider show --subscription $SubscriptionId --namespace $provider --query registrationState --output tsv --only-show-errors
  if ($LASTEXITCODE -ne 0) { throw "Cannot read provider $provider" }
  if ($state -ne 'Registered') { Write-Warning "$provider is $state. Register only required providers deliberately before the chosen lab." }
}
Write-Output 'NEXT: inspect regional VM/SKU quota, policy restrictions, resource permissions, role-assignment permissions, and the current cost estimate. This read-only check cannot guarantee them.'
