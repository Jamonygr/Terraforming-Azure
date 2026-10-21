[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $BlobHost,
    [Parameter(Mandatory)] [string] $ExpectedPrivateIp,
    [ValidateSet('Baseline', 'Break', 'Repair')] [string] $Mode = 'Baseline'
)
$ErrorActionPreference = 'Stop'
$hostsPath = Join-Path $env:SystemRoot 'System32/drivers/etc/hosts'
$marker = '# TFA-023-controlled-dns'
if ($Mode -in @('Break', 'Repair')) {
    $lines = @(Get-Content -LiteralPath $hostsPath | Where-Object { $_ -notlike "*$marker*" })
    if ($Mode -eq 'Break') { $lines += "192.0.2.10 $BlobHost $marker" }
    Set-Content -LiteralPath $hostsPath -Value $lines -Encoding ascii
    Clear-DnsClientCache
}
$records = Resolve-DnsName -Name $BlobHost -ErrorAction Continue
$records | Format-Table Name, Type, IPAddress -AutoSize
$addresses = @($records | Where-Object IPAddress | Select-Object -ExpandProperty IPAddress)
Write-Output "Expected private address present: $($addresses -contains $ExpectedPrivateIp)"
Test-NetConnection -ComputerName $BlobHost -Port 443 -InformationLevel Detailed
try {
    $response = Invoke-WebRequest -Uri "https://$BlobHost/?comp=list" -UseBasicParsing -TimeoutSec 15
    Write-Output "Unauthenticated HTTP status: $([int]$response.StatusCode)"
} catch {
    if ($_.Exception.Response) {
        Write-Output "HTTP service reached; unauthenticated status: $([int]$_.Exception.Response.StatusCode)"
    } else {
        Write-Output "Transport/name failure: $($_.Exception.Message)"
    }
}
