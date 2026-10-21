# Runs inside the optional server VM through Azure Run Command. No public listener is exposed.
$ErrorActionPreference = 'Stop'
if (-not (Get-NetFirewallRule -DisplayName 'TFA008 probe HTTPS port' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'TFA008 probe HTTPS port' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 443 -RemoteAddress 10.8.1.0/24 | Out-Null
}
$listenerScript = Join-Path $env:ProgramData 'TFA008-Listener.ps1'
@'
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, 443)
$listener.Start()
try { while ($true) { $client = $listener.AcceptTcpClient(); $client.Dispose() } }
finally { $listener.Stop() }
'@ | Set-Content -LiteralPath $listenerScript -Encoding utf8
if (-not (Get-ScheduledTask -TaskName 'TFA008-Listener' -ErrorAction SilentlyContinue)) {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -File `"$listenerScript`""
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName 'TFA008-Listener' -Action $action -Principal $principal | Out-Null
}
Start-ScheduledTask -TaskName 'TFA008-Listener'
'Listener task started; this is a TCP reachability probe, not a TLS web server.'
