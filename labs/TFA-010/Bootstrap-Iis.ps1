[CmdletBinding()]
param(
    [string]$WebRoot = 'C:\inetpub\wwwroot',
    [string]$PageMessage = 'Terraforming Azure TFA-010',
    [uri]$VerificationUri = 'http://localhost/Default.htm'
)
$ErrorActionPreference = 'Stop'
$installation = Install-WindowsFeature -Name Web-Server -IncludeManagementTools -ErrorAction Stop
if (-not $installation.Success) { throw 'IIS feature installation reported failure; do not publish a success page.' }
if ($installation.RestartNeeded -eq 'Yes') { throw 'IIS installation requires a restart; restart deliberately and rerun bootstrap before claiming success.' }
Start-Service -Name W3SVC -ErrorAction Stop
New-Item -ItemType Directory -Path $WebRoot -Force -ErrorAction Stop | Out-Null
$page = Join-Path $WebRoot 'Default.htm'
Set-Content -LiteralPath $page -Value $PageMessage -Encoding UTF8 -ErrorAction Stop
$response = Invoke-WebRequest -Uri $VerificationUri -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
if ($response.StatusCode -ne 200 -or -not ([string]$response.Content).Contains($PageMessage)) {
    throw 'IIS did not return HTTP 200 with the expected training page.'
}
Write-Output 'IIS feature installed, W3SVC started and the expected HTTP page verified.'
