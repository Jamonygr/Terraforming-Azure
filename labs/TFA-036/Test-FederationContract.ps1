[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
$data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
$subject = "repo:$($data.repository):environment:$($data.environment)"
if ($data.issuer -cne 'https://token.actions.githubusercontent.com' -or $data.audience -cne 'api://AzureADTokenExchange' -or $data.subject -cne $subject -or $data.id_token_permission -cne 'write') {
    throw 'Federation contract mismatch; no token was requested or validated.'
}
[pscustomobject]@{ evidence_mode='authored_fixture'; subject=$subject; trust_contract_matches=$true; token_exchange='not_run' }
