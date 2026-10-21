[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][ipaddress]$ExpectedBlobIp,
    [Parameter(Mandatory)][ipaddress]$ExpectedCorporateIp
)
$ErrorActionPreference = 'Stop'
$data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
$blobAnswers = @($data.corporate_to_azure | Where-Object { $_.Type -eq 'A' } | ForEach-Object { $_.IPAddress } | Sort-Object -Unique)
$corpAnswers = @($data.azure_to_corporate | Where-Object { $_.Type -eq 'A' } | ForEach-Object { $_.IPAddress } | Sort-Object -Unique)
if ($blobAnswers.Count -ne 1 -or $blobAnswers[0] -cne $ExpectedBlobIp.ToString()) { throw 'Corporate-to-Azure answer does not equal the designated Blob endpoint.' }
if ($corpAnswers.Count -ne 1 -or $corpAnswers[0] -cne $ExpectedCorporateIp.ToString()) { throw 'Azure-to-corporate answer does not equal the designated corporate server.' }
[pscustomobject]@{ evidence_mode='saved_response'; blob_ip=$blobAnswers[0]; corporate_ip=$corpAnswers[0]; both_directions=$true }
