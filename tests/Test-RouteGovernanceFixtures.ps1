[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $PSScriptRoot 'fixtures/lesson-evidence'
$routes = Join-Path $fixture 'effective-routes.json'
$routeParser = Join-Path $root 'labs/TFA-013/Test-RouteEvidence.ps1'
$discard = & $routeParser -EffectiveRoutesPath $routes -NextHopPath (Join-Path $fixture 'next-hop-discard.json') -Destination '10.60.0.4' -ExpectedNextHop None
if (-not $discard.discards_traffic -or $discard.selected_prefix -cne '10.60.0.0/16') { throw 'The longest matching user discard route was not selected.' }
$local = & $routeParser -EffectiveRoutesPath $routes -NextHopPath (Join-Path $fixture 'next-hop-local.json') -Destination '10.13.1.10' -ExpectedNextHop VnetLocal
if ($local.discards_traffic -or $local.selected_prefix -cne '10.13.0.0/16') { throw 'The valid local VNet route was mistaken for the broader discard.' }
$rejected = $false
try { & $routeParser -EffectiveRoutesPath $routes -NextHopPath (Join-Path $fixture 'next-hop-local.json') -Destination '10.60.0.4' -ExpectedNextHop VnetLocal | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'Conflicting effective-route and next-hop responses were accepted.' }
$rg = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-tfa032-fixture'
$policy = $rg + '/providers/Microsoft.Authorization/policyAssignments/require-course-tag'
$governanceParser = Join-Path $root 'labs/TFA-032/Test-GovernanceEvidence.ps1'
$good = Join-Path $fixture 'governance.json'
$result = & $governanceParser -Path $good -ExpectedResourceGroupId $rg -ExpectedPolicyAssignmentId $policy
if (-not $result.lock_removed -or -not $result.notification_observed -or $result.spending_stopped_by_budget -or $result.spend_percent -ne 85) { throw 'The governance observations were misinterpreted.' }
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$directory = Join-Path $temporaryRoot ('tfa-governance-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory | Out-Null
try {
    foreach ($case in @('wrong-error','wrong-policy','below-threshold','no-notification','still-locked','failed-unlock')) {
        $data = Get-Content -LiteralPath $good -Raw | ConvertFrom-Json
        switch ($case) {
            'wrong-error' { $data.denied_request.error.code = 'AuthorizationFailed' }
            'wrong-policy' { $data.denied_request.error.additionalInfo[0].info.policyAssignmentId = $policy + '-other' }
            'below-threshold' { $data.budget.properties.currentSpend.amount = 79 }
            'no-notification' { $data.notification_event.observed = $false }
            'still-locked' { $data.locks_after = @($data.locks_before) }
            'failed-unlock' { $data.unlock_apply_exit_code = 1 }
        }
        $bad = Join-Path $directory "$case.json"
        $data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $bad -Encoding utf8
        $rejected = $false
        try { & $governanceParser -Path $bad -ExpectedResourceGroupId $rg -ExpectedPolicyAssignmentId $policy | Out-Null } catch { $rejected = $true }
        if (-not $rejected) { throw "Invalid governance evidence was accepted: $case" }
    }
}
finally {
    $resolved = [IO.Path]::GetFullPath($directory)
    if ($resolved.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -match '^tfa-governance-[a-f0-9]{32}$') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
Write-Output 'PASS saved route/governance fixtures: longest-prefix local/discard decisions, conflicting next-hop rejection, scoped policy denial, notification threshold/event, successful unlock and six malformed evidence rejections.'
