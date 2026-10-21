[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$ExpectedResourceGroupId,
    [Parameter(Mandatory)][string]$ExpectedPolicyAssignmentId
)
$ErrorActionPreference = 'Stop'
$data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
if ($data.denied_request.error.code -cne 'RequestDisallowedByPolicy') { throw 'A failed request is not necessarily a policy denial.' }
$violations = @($data.denied_request.error.additionalInfo | Where-Object { $_.type -ceq 'PolicyViolation' })
if (-not ($violations | Where-Object { $_.info.policyAssignmentId -ceq $ExpectedPolicyAssignmentId })) { throw 'The denial does not identify the expected scoped policy assignment.' }
if (-not $data.denied_resource_id.StartsWith($ExpectedResourceGroupId+'/', [StringComparison]::OrdinalIgnoreCase)) { throw 'The denied resource is outside the owned resource group.' }
$budget = $data.budget.properties
if (-not $data.budget.id.StartsWith($ExpectedResourceGroupId+'/providers/Microsoft.Consumption/budgets/',[StringComparison]::OrdinalIgnoreCase)) { throw 'Budget evidence belongs to a different scope.' }
$notification = @($budget.notifications.PSObject.Properties | ForEach-Object { $_.Value } | Where-Object { $_.enabled -eq $true -and $_.operator -ceq 'GreaterThanOrEqualTo' -and @($_.contactEmails).Count -gt 0 }) | Select-Object -First 1
if (-not $notification -or $budget.amount -le 0) { throw 'No usable enabled budget notification threshold exists.' }
$fraction = 100*[double]$budget.currentSpend.amount/[double]$budget.amount
if ($fraction -lt [double]$notification.threshold) { throw 'The saved spend has not reached the claimed notification threshold.' }
if (-not $data.notification_event.observed -or $data.notification_event.budget_id -cne $data.budget.id) { throw 'A crossed threshold alone does not prove a notification event was observed.' }
$locks = @($data.locks_before | Where-Object { $_.properties.level -ceq 'CanNotDelete' -and $_.id.StartsWith($ExpectedResourceGroupId+'/',[StringComparison]::OrdinalIgnoreCase) })
if (-not $locks.Count -or @($data.locks_after).Count -ne 0 -or $data.unlock_apply_exit_code -ne 0) { throw 'The owned deletion lock has not been demonstrably removed.' }
if ($data.resource_still_exists_after_notification -ne $true) { throw 'This fixture must demonstrate that a budget notification does not stop or remove the resource.' }
[pscustomobject]@{ evidence_mode='normalized_fixture'; policy_denial_identified=$true; spend_percent=$fraction; notification_observed=$true; spending_stopped_by_budget=$false; lock_removed=$true }
