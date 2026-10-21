[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
$data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
foreach ($case in $data) {
    if (@($case.dns_answers).Count -ne 1 -or $case.dns_answers[0] -cne $case.expected_ip) { $diagnosis = 'dns-wrong' }
    elseif ($case.selected_next_hop -ceq 'None') { $diagnosis = 'route-drop' }
    elseif ($case.nsg_access -ceq 'Deny') { $diagnosis = 'nsg-block' }
    elseif ($case.w3svc_status -ceq 'Stopped') { $diagnosis = 'app-stopped' }
    elseif ($case.tcp_succeeded -eq $true -and $case.w3svc_status -ceq 'Running' -and $case.nsg_access -ceq 'Allow') { $diagnosis = 'healthy' }
    else { $diagnosis = 'unresolved' }
    if ($diagnosis -cne $case.expected_diagnosis) { throw "Evidence for $($case.name) does not support the expected diagnosis; observed $diagnosis." }
    [pscustomobject]@{ evidence_mode='normalized_fixture'; name=$case.name; diagnosis=$diagnosis }
}
