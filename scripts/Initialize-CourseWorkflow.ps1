# Called inside the same PowerShell step as Terraform; secrets remain process-local.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
foreach ($key in @('ARM_CLIENT_ID','ARM_TENANT_ID','ARM_SUBSCRIPTION_ID','TFSTATE_ACCOUNT','TF_VAR_admin_password','TF_VAR_operator_cidrs')) {
  if (-not [Environment]::GetEnvironmentVariable($key)) { throw "Configure required workflow setting: $key" }
}
$null = $env:TF_VAR_operator_cidrs | ConvertFrom-Json
$env:TF_VAR_subscription_id = $env:ARM_SUBSCRIPTION_ID
$env:TF_VAR_stage = $env:COURSE_STAGE
if (-not $env:TF_VAR_location) { $env:TF_VAR_location = 'westeurope' }
if (-not $env:TF_VAR_name_prefix) { $env:TF_VAR_name_prefix = 'tfazure' }
if ($env:COURSE_STAGE -in @('applications','hybrid')) {
  if (-not $env:LAB_CERTIFICATE_PFX -or -not $env:TF_VAR_certificate_password) { throw 'Applications/hybrid require the training PFX and certificate password secrets.' }
  $secretDir = Join-Path $env:GITHUB_WORKSPACE '.secrets'
  New-Item -ItemType Directory -Path $secretDir -Force | Out-Null
  $env:TF_VAR_certificate_path = Join-Path $secretDir 'lab.pfx'
  [IO.File]::WriteAllBytes($env:TF_VAR_certificate_path, [Convert]::FromBase64String($env:LAB_CERTIFICATE_PFX))
} else {
  Remove-Item Env:TF_VAR_certificate_password -ErrorAction SilentlyContinue
}
if ($env:COURSE_STAGE -ne 'hybrid') { Remove-Item Env:TF_VAR_vpn_shared_key -ErrorAction SilentlyContinue }
elseif (-not $env:TF_VAR_vpn_shared_key) { throw 'Hybrid requires the VPN shared-key secret.' }
