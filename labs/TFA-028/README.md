# TFA-028 - Monitoring and diagnostic evidence

<!-- lab-metadata:start -->
**Phase 4:** Private platforms

**Learning target:** 75 minutes · **Cost tier:** Moderate · **Run mode:** `azure`

**Prerequisites:** [TFA-027 — Application Gateway WAF and private IIS](../TFA-027/README.md)
<!-- lab-metadata:end -->

[Course home](../../README.md) | [Previous lab](../TFA-027/README.md) | [Next lab](../TFA-029/README.md)

## Why this lab exists

A successful resource deployment does not show whether an application works. Monitoring needs an agent, collection rules, a destination, and a repeatable evidence query.

## What you will learn

Collect diagnostics and guest telemetry, query evidence, and validate an alert. Your evidence must distinguish configuration intent from the observed result: Heartbeat, exact event row and alert lifecycle are separate evidence items.

## Predict the mechanism

The agent sends selected guest events through a DCR to a workspace; platform diagnostic settings collect a different source. A scheduled query rule evaluates recently ingested records on a cadence. A synthetic marker lets the learner distinguish missing collection from a wrong query and from an alert that simply has not evaluated yet.

Before running commands, write the expected result: **Heartbeat, exact event row and alert lifecycle are separate evidence items.** Then explain what would change in this controlled failure: Change only the query marker, compare ingested records with no match, restore it. Record your prediction before inspecting the outcome.

## Concepts before commands

Azure Monitor Agent runs under the VM system-assigned identity. A DCR selects Windows events and performance counters; an association binds that rule to the VM. Log Analytics is the destination. Platform diagnostic settings are a separate mechanism for resource logs. Explicit NAT supplies outbound connectivity for agent endpoints without exposing a VM inbound port.

## Architecture

<!-- lab-diagram:start -->
![TFA-028 teaching diagram](../../assets/diagrams/TFA-028.svg)
<!-- lab-diagram:end -->

A private Windows VM, system-assigned identity, NAT egress, Azure Monitor Agent, a Windows DCR and association, and a Log Analytics workspace. A Key Vault diagnostic setting demonstrates platform audit logs alongside guest telemetry.

## Runtime and cost checkpoint

PowerShell 7.4 or newer (under 8), Terraform 1.15.8, Git, and the preceding concepts. Azure CLI, an explicitly selected sandbox subscription, approved permissions and regional quota. AzureRM is pinned to 4.77.0; do not silently upgrade it during the lesson.

Charged resources include one Windows VM, NAT Gateway, Log Analytics ingestion, diagnostic operations and one scheduled log alert evaluated every minute. A daily ingestion cap is not a spending guarantee. Read the selected services in the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/) before apply. A stopped VM can retain charged disks; a gateway/firewall is not stopped by leaving the terminal. Each lab owns its own local state; keep that state until cleanup. Do not reuse another lab's backend or import its resources.

## Step 1 - Read the implementation

Open `versions.tf`, `variables.tf`, `main.tf`, and `outputs.tf` in this directory. Follow the AMA extension, the DCR data sources/streams, the destination name, and the DCR association. Read `queries.kql`. Distinguish a missing Heartbeat from a valid heartbeat with an incorrectly filtered Event query. If a shared Windows VM pattern is referenced, read its [implementation](../../modules/patterns/windows-vm/main.tf) as part of this lesson.

## Step 2 - Plan and build

Run from `labs/TFA-028` in PowerShell 7. Tests use provider mocks or local resources and do not apply Azure infrastructure. Supply real cloud inputs only for your deliberate plan/apply. The example tfvars file is an alternative to environment variables; a real terraform.tfvars value takes precedence over TF_VAR values.

```powershell
$env:TF_VAR_subscription_id = Read-Host 'Explicit Azure subscription ID'
az login
az account set --subscription $env:TF_VAR_subscription_id
$env:TF_VAR_location = 'westeurope'
terraform init
terraform fmt -check
terraform validate
terraform test
$env:TF_VAR_admin_password = Read-Host 'Unique Windows lab password (14+ characters)' -MaskInput
terraform plan -out=lab.tfplan
terraform show lab.tfplan
# Read the whole plan and confirm the subscription, scope, and charged services.
terraform apply lab.tfplan
```

Record what Terraform creates, which values are unknown until apply, and which resources carry ongoing charges. Keep passwords, VPN keys, PFX files, plans, and state out of Git. `sensitive` hides console values; it does not remove them from state.

## Step 3 - Verify with evidence

```powershell
$rg = terraform output -raw resource_group_name
$vm = terraform output -raw ops_vm_name
$workspace = terraform output -raw workspace_id
az vm extension list -g $rg --vm-name $vm -o table
az vm run-command invoke -g $rg -n $vm --command-id RunPowerShellScript --scripts "eventcreate /T ERROR /ID 100 /L APPLICATION /D 'TFA-028 monitoring evidence'"
az monitor log-analytics query -w $workspace --analytics-query "Heartbeat | where TimeGenerated > ago(30m) | summarize LastSeen=max(TimeGenerated) by Computer"
az monitor log-analytics query -w $workspace --analytics-query "Event | where TimeGenerated > ago(1h) | where RenderedDescription contains 'TFA-028' | project TimeGenerated, Computer, RenderedDescription"
```

The agent extension provisions, a recent heartbeat arrives, and the synthetic Application error appears in Event after ingestion. An empty table immediately after apply is not proof of failure. Generate a Key Vault data-plane request and inspect its audit category separately; management-plane activity is not equivalent to a secret read.

Save a short local evidence note with the time, exact probe, observed result, and your explanation. Resource existence, DNS, routing, authorization, and application success are different kinds of evidence.

## Trigger and resolve the synthetic alert

`alerts.tf` creates a stateful scheduled query rule scoped to this workspace: **Count ≥1**, a **five-minute window**, evaluation every minute and automatic mitigation. Its KQL selects Application errors containing the exact training marker. No email, webhook or paging destination is configured; inspect the alert instance in Azure Monitor → Alerts. This keeps notification recipients out of the example.

1. Record `terraform output -raw synthetic_alert_id` and the UTC time before producing the event.
2. Run the `eventcreate` command above once and repeat the exact Event query until the matching row appears. Allow up to 15 minutes for ingestion; stop and investigate the DCR/agent if it does not arrive. Do not keep emitting events while testing resolution.
3. Open Monitor → Alerts, scope to this lab resource group, and select the rule's fired instance. Record its rule ID, Fired time and monitor condition. A rule resource merely existing is not an alert firing.
4. After the event leaves the five-minute query window, wait for Azure's stateful resolution evaluations. Allow a bounded additional 20 minutes, refresh the same alert instance and record Resolved. If it stays Fired, query the last five minutes for additional matching events before changing thresholds.

```powershell
$alertRule = terraform output -raw synthetic_alert_id
az resource show --ids $alertRule --query '{name:name,enabled:properties.enabled,window:properties.windowSize,autoMitigate:properties.autoMitigate}' -o json
az monitor log-analytics query -w $workspace --analytics-query "Event | where TimeGenerated > ago(5m) | where EventLog == 'Application' and EventLevelName == 'Error' | where RenderedDescription contains 'TFA-028 monitoring evidence' | count"
```

For a controlled repair, change the query marker to an intentionally unmatched string, plan/apply it, emit the original event and compare the Event query with the alert query. Restore the original marker and retest. The offline test asserts query marker, threshold, time window and workspace scope; the response fixtures model Fired/Resolved without contacting Azure. These authored runtime instructions were not executed during course validation.

## Troubleshooting

Check VM outbound DNS/HTTPS, extension status, DCR association, stream names, XPath filters, workspace destination, and query time window. Avoid installing the retired Log Analytics/MMA agent alongside AMA to mask a collection mistake.

## Challenge

Change the collection interval to 120 seconds and explain the signal/cost tradeoff. Add an informational-event query only after adjusting the XPath, then restore the original noise level.

## Knowledge check

Complete the five questions in [quiz.json](quiz.json), or use the course site's interactive quiz. Explain each answer before revealing its explanation. The quiz checks reasoning; it is not a substitute for the evidence above.

## Cleanup

```powershell
$cleanupGroup = terraform output -raw resource_group_name
if ($LASTEXITCODE -ne 0 -or -not $cleanupGroup) { throw 'Capture the actual lab group before planning destruction.' }
terraform plan -destroy -out=cleanup.tfplan
if ($LASTEXITCODE -ne 0) { throw 'Destroy plan failed: do not apply an older cleanup plan.' }
terraform show cleanup.tfplan
if ($LASTEXITCODE -ne 0) { throw 'Destroy plan could not be reviewed: stop before apply.' }
terraform apply cleanup.tfplan
if ($LASTEXITCODE -ne 0) { throw 'Destroy failed: retain state and investigate remaining resources before claiming cleanup.' }
$remaining = @(terraform state list)
if ($LASTEXITCODE -ne 0 -or $remaining.Count) { throw 'Cleanup left managed objects or state could not be read.' }
# Check the Azure resource group no longer exists after successful destroy.
$groupExists = az group exists --subscription $env:TF_VAR_subscription_id --name $cleanupGroup
if ($LASTEXITCODE -ne 0 -or $groupExists -ne 'false') { throw 'The owned group is not confirmed deleted. Keep state and investigate.' }
Remove-Item Env:TF_VAR_admin_password -ErrorAction SilentlyContinue
```

A successful destroy and an empty state are the expected result. The cleanup command uses the captured group, including a changed prefix. Soft-deleted vaults and retained logs can outlive their active resource; review the relevant Azure lifecycle and cost settings. Do not commit generated plans or state as evidence.

## Completion criteria

- You can explain why this design produces the observed behavior.
- You captured the required success evidence and investigated the controlled limitation or failure.
- You completed the challenge and five questions.
- You reviewed and completed cleanup, or recorded an explicit owner and deadline for intentionally retained resources.

## Continue learning

[Official documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection) | [Continue to TFA-029](../TFA-029/README.md)

## Evidence contract

Emit one named Application event; query it; inspect the scheduled rule Fired then Resolved instance. Heartbeat, exact event row and alert lifecycle are separate evidence items.

See the [40-lab evidence map](../../docs/curriculum-evidence.md) for source paths, validation level and cleanup dependencies. Authored Azure commands are learner exercises; passing local checks does not establish a live deployment.

The local evidence parser is [Test-AlertEvidence.ps1](Test-AlertEvidence.ps1). Run the shared regression from the repository root: `pwsh -NoProfile -File tests/Test-LessonEvidence.ps1`. Its [synthetic fixtures](../../tests/fixtures/lesson-evidence/README.md) validate response interpretation without Azure access.
