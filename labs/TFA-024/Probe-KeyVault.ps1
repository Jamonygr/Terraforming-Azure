[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $VaultUri,
    [Parameter(Mandatory)] [string] $ClientId,
    [ValidateSet('Seed', 'Read')] [string] $Action = 'Read'
)
$ErrorActionPreference = 'Stop'
# This runs inside the lab VM. Never print or persist the short-lived access token.
$tokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net&client_id=$ClientId"
$token = Invoke-RestMethod -Uri $tokenUri -Headers @{ Metadata = 'true' }
$headers = @{ Authorization = "Bearer $($token.access_token)" }
$secretUri = "$($VaultUri.TrimEnd('/'))/secrets/tfa-runtime-demo?api-version=7.4"
try {
    if ($Action -eq 'Seed') {
        # Deliberately non-secret demonstration text, created at runtime, never Terraform state.
        $body = @{ value = 'TFA-024-runtime-demonstration-only' } | ConvertTo-Json
        $null = Invoke-RestMethod -Uri $secretUri -Method Put -Headers $headers -ContentType 'application/json' -Body $body
        Write-Output 'Seeded the dummy runtime secret through the VM managed identity.'
    } else {
        $secret = Invoke-RestMethod -Uri $secretUri -Method Get -Headers $headers
        Write-Output "Managed-identity read succeeded: $($secret.value -eq 'TFA-024-runtime-demonstration-only')"
        Write-Output "Secret version ID: $($secret.id)"
    }
} catch {
    if ($_.Exception.Response) { Write-Output "Key Vault HTTP status: $([int]$_.Exception.Response.StatusCode)" }
    throw
} finally {
    $headers.Clear()
    $token = $null
}
