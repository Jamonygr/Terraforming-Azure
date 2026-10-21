[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]{3,24}$')][string]$StorageAccountName,
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9-]{3,24}$')][string]$KeyVaultName,
    [Parameter(Mandatory)][ipaddress]$ExpectedBlobIp,
    [Parameter(Mandatory)][ipaddress]$ExpectedVaultIp,
    [ValidateSet('Seed', 'Probe')][string]$Mode = 'Probe',
    [ValidateRange(1,40)][int]$MaxAttempts = 20,
    [ValidateRange(0,30)][int]$RetryDelaySeconds = 15,
    # A complete synthetic adapter is used only by offline behavior tests.
    [hashtable]$Adapter
)
$ErrorActionPreference = 'Stop'
$fixture = $null -ne $Adapter
if ($fixture) {
    foreach ($key in @('Resolve','Request','Token','Sleep')) {
        if (-not ($Adapter[$key] -is [scriptblock])) { throw "Synthetic adapter must provide $key; real fallbacks are forbidden." }
    }
} else {
    $Adapter = @{
        Resolve = { param($name) @(Resolve-DnsName -Name $name -Type A -DnsOnly -QuickTimeout -ErrorAction Stop | Where-Object IPAddress | Select-Object -ExpandProperty IPAddress) }
        Sleep = { param($seconds) Start-Sleep -Seconds $seconds }
        Token = {
            param($resource)
            $escaped = [Uri]::EscapeDataString($resource)
            try {
                $token = (Invoke-RestMethod -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$escaped" -Headers @{Metadata='true'} -TimeoutSec 15 -UseBasicParsing).access_token
                if (-not $token) { throw 'Missing token.' }
                return $token
            } catch { throw 'Managed identity token acquisition failed. Check VM identity and IMDS; response details are suppressed.' }
        }
        Request = { param($request) Invoke-WebRequest @request }
    }
}
foreach ($target in @($ExpectedBlobIp,$ExpectedVaultIp)) {
    if ($target.ToString() -notmatch '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)') { throw 'Expected endpoint targets must be private IPv4 addresses from Terraform outputs.' }
}
function Wait-ExactPrivateDns([string]$Name, [string]$Expected) {
    for ($attempt=1; $attempt -le $MaxAttempts; $attempt++) {
        $addresses = @()
        try { $addresses = @(& $Adapter.Resolve $Name | Sort-Object -Unique) } catch { $addresses = @() }
        if ($addresses.Count -eq 1 -and $addresses[0] -eq $Expected) {
            Write-Output "DNS matched configured private endpoint: $Name -> $Expected"
            return
        }
        if ($attempt -eq $MaxAttempts) { throw "DNS target mismatch for $Name after $MaxAttempts attempts; expected $Expected. Check zones, caches and forwarding." }
        & $Adapter.Sleep $RetryDelaySeconds
    }
}
function Invoke-LabRequest {
    param([string]$Uri, [string]$Method, [hashtable]$Headers, [string]$Body='', [string]$ContentType='application/json', [switch]$AllowConflict)
    for ($attempt=1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            if ($Headers.ContainsKey('x-ms-version')) { $Headers['x-ms-date']=[DateTime]::UtcNow.ToString('R',[Globalization.CultureInfo]::InvariantCulture) }
            $request=@{Uri=$Uri; Method=$Method; Headers=$Headers; UseBasicParsing=$true; TimeoutSec=30}
            if ($Method -ne 'Get') { $request.Body=$Body; $request.ContentType=$ContentType }
            return & $Adapter.Request $request
        } catch {
            $status=0
            if ($_.Exception.Data.Contains('StatusCode')) { $status=[int]$_.Exception.Data['StatusCode'] }
            elseif ($_.Exception.Response) { $status=[int]$_.Exception.Response.StatusCode }
            if ($AllowConflict -and $status -eq 409) { return }
            # Never echo exception text, request headers, token or response body.
            if ($attempt -eq $MaxAttempts -or $status -notin @(0,403,429,503)) { throw "Private $Method request failed (HTTP $status) after $attempt attempt(s). Inspect DNS, RBAC and service diagnostics." }
            & $Adapter.Sleep $RetryDelaySeconds
        }
    }
}
$blobHost="$StorageAccountName.blob.core.windows.net"
$vaultHost="$KeyVaultName.vault.azure.net"
Wait-ExactPrivateDns $blobHost $ExpectedBlobIp.ToString()
Wait-ExactPrivateDns $vaultHost $ExpectedVaultIp.ToString()
$blobHeaders=@{Authorization="Bearer $(& $Adapter.Token 'https://storage.azure.com/')"; 'x-ms-version'='2023-11-03'}
$vaultHeaders=@{Authorization="Bearer $(& $Adapter.Token 'https://vault.azure.net')"}
$blobUri="https://$blobHost/sample/message.txt"
$secretUri="https://$vaultHost/secrets/lab-message?api-version=7.4"
try {
    if ($Mode -eq 'Seed') {
        Invoke-LabRequest -Uri "https://$blobHost/sample?restype=container" -Method Put -Headers $blobHeaders -AllowConflict | Out-Null
        $blobHeaders['x-ms-blob-type']='BlockBlob'
        Invoke-LabRequest -Uri $blobUri -Method Put -Headers $blobHeaders -ContentType 'text/plain' -Body 'Hello from private Terraforming Azure storage.' | Out-Null
        $blobHeaders.Remove('x-ms-blob-type') | Out-Null
        Invoke-LabRequest -Uri $secretUri -Method Put -Headers $vaultHeaders -Body '{"value":"This is sample lab data, not a production credential."}' | Out-Null
    }
    $blob=Invoke-LabRequest -Uri $blobUri -Method Get -Headers $blobHeaders
    $secret=Invoke-LabRequest -Uri $secretUri -Method Get -Headers $vaultHeaders
    if ($blob.StatusCode -ne 200 -or $secret.StatusCode -ne 200) { throw 'Private data response did not return HTTP 200.' }
    $source=if ($fixture) {'SYNTHETIC FIXTURE'} else {'VM RUNTIME'}
    Write-Output "PASS ($source): expected DNS targets and authorized sample reads. Tokens and secret values suppressed."
} finally {
    $blobHeaders.Clear(); $vaultHeaders.Clear()
}
