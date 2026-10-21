$ErrorActionPreference = 'Stop'
Install-WindowsFeature -Name Web-Server -IncludeManagementTools | Out-Null
$html = @"
<!doctype html><html lang="en"><meta charset="utf-8"><title>Terraforming Azure</title>
<style>body{font:20px Segoe UI;background:#061a2d;color:#e4f7ff;padding:4rem}h1{color:#5be0d5}</style>
<h1>Terraforming Azure - private IIS</h1><p>Backend: $env:COMPUTERNAME</p>
<p>Public HTTPS terminates at WAF. This VM has a private address only.</p></html>
"@
Set-Content -LiteralPath C:\inetpub\wwwroot\index.html -Value $html -Encoding UTF8
Set-Content -LiteralPath C:\inetpub\wwwroot\health.txt -Value 'healthy' -Encoding ASCII
Import-Module WebAdministration
Set-ItemProperty 'IIS:\Sites\Default Web Site' -Name logFile.logFormat -Value W3C
Set-ItemProperty 'IIS:\Sites\Default Web Site' -Name logFile.period -Value Hourly
New-NetFirewallRule -DisplayName 'Terraforming Azure HTTP' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80 -ErrorAction SilentlyContinue | Out-Null
Start-Service W3SVC
if ((Invoke-WebRequest -Uri http://localhost/health.txt -UseBasicParsing).StatusCode -ne 200) { throw 'IIS health check failed.' }
Write-Output "IIS ready: $env:COMPUTERNAME"
