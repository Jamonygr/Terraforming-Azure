[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]{3,24}$')][string]$StorageAccountName,
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9-]{3,24}$')][string]$KeyVaultName,
    [ValidateSet('Seed', 'Probe')][string]$Mode = 'Probe'
)
$ErrorActionPreference = 'Stop'

# Run inside a capstone VM with a system-assigned identity, never on the public
# Terraform runner. ops01 has contributor/officer roles; the other VMs read only.
function Get-ManagedIdentityToken([string]$Resource) {
    $escaped = [Uri]::EscapeDataString($Resource)
    $uri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$escaped"
    (Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Metadata = 'true' } -UseBasicParsing).access_token
}

function Invoke-LabRequest {
    param([string]$Uri, [string]$Method, [hashtable]$Headers, [string]$Body = '', [string]$ContentType = 'application/json', [switch]$AllowConflict)
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        try {
            if ($Headers.ContainsKey('x-ms-version')) {
                $Headers['x-ms-date'] = [DateTime]::UtcNow.ToString('R', [Globalization.CultureInfo]::InvariantCulture)
            }
            $request = @{ Uri = $Uri; Method = $Method; Headers = $Headers; UseBasicParsing = $true }
            if ($Method -ne 'Get') { $request.Body = $Body; $request.ContentType = $ContentType }
            return Invoke-WebRequest @request
        } catch {
            $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            if ($AllowConflict -and $status -eq 409) { return }
            # New role assignments and private DNS records can take several minutes.
            if ($attempt -eq 12 -or ($status -notin @(0, 403, 429, 503))) { throw }
            Start-Sleep -Seconds 15
        }
    }
}

$blobHost = "$StorageAccountName.blob.core.windows.net"
$vaultHost = "$KeyVaultName.vault.azure.net"
foreach ($name in @($blobHost, $vaultHost)) {
    $addresses = @(Resolve-DnsName -Name $name -Type A -DnsOnly -ErrorAction Stop | Where-Object IPAddress | Select-Object -ExpandProperty IPAddress)
    if (-not ($addresses | Where-Object { $_ -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' })) {
        throw "$name did not resolve to an RFC1918 private address: $($addresses -join ', ')"
    }
    Write-Output "PRIVATE DNS: $name -> $($addresses -join ', ')"
}
$blobHeaders = @{ Authorization = "Bearer $(Get-ManagedIdentityToken 'https://storage.azure.com/')"; 'x-ms-version' = '2023-11-03' }
$vaultHeaders = @{ Authorization = "Bearer $(Get-ManagedIdentityToken 'https://vault.azure.net')" }
$blobUri = "https://$blobHost/sample/message.txt"
$secretUri = "https://$vaultHost/secrets/lab-message?api-version=7.4"
if ($Mode -eq 'Seed') {
    Invoke-LabRequest -Uri "https://$blobHost/sample?restype=container" -Method Put -Headers $blobHeaders -AllowConflict | Out-Null
    $blobHeaders['x-ms-blob-type'] = 'BlockBlob'
    Invoke-LabRequest -Uri $blobUri -Method Put -Headers $blobHeaders -ContentType 'text/plain' -Body 'Hello from private Terraforming Azure storage.' | Out-Null
    $blobHeaders.Remove('x-ms-blob-type')
    Invoke-LabRequest -Uri $secretUri -Method Put -Headers $vaultHeaders -Body '{"value":"This is sample lab data, not a production credential."}' | Out-Null
    Write-Output 'Created/updated sample/message.txt and Key Vault lab-message using managed identity.'
}
$blob = Invoke-LabRequest -Uri $blobUri -Method Get -Headers $blobHeaders
$secret = Invoke-LabRequest -Uri $secretUri -Method Get -Headers $vaultHeaders
if ($blob.StatusCode -ne 200 -or $secret.StatusCode -ne 200) { throw 'Private data probe failed.' }
Write-Output "PASS: managed identity read Blob and Key Vault over HTTPS from $env:COMPUTERNAME."
Write-Output 'Only synthetic sample data was created. Tokens and secret values were not printed.'
