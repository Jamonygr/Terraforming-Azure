# TFA-031 - Hybrid DNS with Private Resolver

<!-- lab-metadata:start -->
**Phase 5:** Hybrid operations

**Learning target:** 120 minutes · **Cost tier:** High · **Run mode:** `azure`

**Prerequisites:** [TFA-030 — Simulated on-premises connectivity](../TFA-030/README.md)
<!-- lab-metadata:end -->

[Course home](../../README.md) | [Previous lab](../TFA-030/README.md) | [Next lab](../TFA-032/README.md)

## Why this lab exists

A connected remote host can still resolve a storage name to its public address. Hybrid DNS must carry the query to a resolver that sees the private zone.

## What you will learn

Resolve Azure private services and corporate lab names across the VPN. Your evidence must distinguish configuration intent from the observed result: Blob resolves to its exact private endpoint and the corporate record resolves to 10.131.2.4.

## Predict the mechanism

Hybrid DNS has two independent directions. The corporate server forwards original Azure service namespaces to the resolver inbound IP; an Azure-linked outbound ruleset forwards only the corporate suffix back to corporate DNS. Keep suffix ownership explicit to avoid forwarding loops and compare answers to exact expected endpoint addresses.

Before running commands, write the expected result: **Blob resolves to its exact private endpoint and the corporate record resolves to 10.131.2.4.** Then explain what would change in this controlled failure: Disable only the corporate rule, clear/expire caches, verify one-direction failure and restore. Record your prediction before inspecting the outcome.

## Concepts before commands

The simulated-site Windows DNS server conditionally forwards the Blob public service zone and its privatelink zone to an Azure DNS Private Resolver inbound IP across the VPN. The private zone is linked to the Azure VNet. The reverse direction is implemented separately: an Azure-linked ruleset sends corp.tfa.internal. to 10.131.2.4:53 through a delegated outbound endpoint and the VPN. The two suffixes never forward back to their own originating resolver, preventing a loop. The DNS VM uses explicit `-Server` queries in the exercise; it is not silently installed as every VNet client's default DNS server.

## Architecture

<!-- lab-diagram:start -->
![TFA-031 teaching diagram](../../assets/diagrams/TFA-031.svg)
<!-- lab-diagram:end -->

A standalone two-gateway hybrid network, private-only Blob endpoint and DNS zone, a delegated resolver subnet with static inbound IP `10.31.1.4`, and Windows DNS with conditional forwarders at `10.131.2.4`.

## Runtime and cost checkpoint

PowerShell 7.4 or newer (under 8), Terraform 1.15.8, Git, and the preceding concepts. Azure CLI, an explicitly selected sandbox subscription, approved permissions and regional quota. AzureRM is pinned to 4.77.0; do not silently upgrade it during the lesson.

Charged resources include two VPN gateways, DNS Resolver inbound/outbound endpoints and ruleset, private endpoint, DNS zones, two Windows VMs and two NAT Gateways. Read the selected services in the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/) before apply. A stopped VM can retain charged disks; a gateway/firewall is not stopped by leaving the terminal. Each lab owns its own local state; keep that state until cleanup. Do not reuse another lab's backend or import its resources.

## Step 1 - Read the implementation

Open `versions.tf`, `variables.tf`, `main.tf`, and `outputs.tf` in this directory. Follow the hostname query: simulated Windows DNS -> VPN -> resolver inbound endpoint -> linked private zone -> private endpoint A record. The resolver subnet must be dedicated and delegated. Storage creation uses ARM-only provider behavior because your laptop has no private data-plane path. If a shared Windows VM pattern is referenced, read its [implementation](../../modules/patterns/windows-vm/main.tf) as part of this lesson.

## Step 2 - Plan and build

Run from `labs/TFA-031` in PowerShell 7. Tests use provider mocks or local resources and do not apply Azure infrastructure. Supply real cloud inputs only for your deliberate plan/apply. The example tfvars file is an alternative to environment variables; a real terraform.tfvars value takes precedence over TF_VAR values.

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
$env:TF_VAR_vpn_shared_key = Read-Host 'Unique shared tunnel key (24+ characters)' -MaskInput
terraform plan -out=lab.tfplan
terraform show lab.tfplan
# Read the whole plan and confirm the subscription, scope, and charged services.
terraform apply lab.tfplan
```

Record what Terraform creates, which values are unknown until apply, and which resources carry ongoing charges. Keep passwords, VPN keys, PFX files, plans, and state out of Git. `sensitive` hides console values; it does not remove them from state.

## Step 3 - Verify with evidence

```powershell
$rg = terraform output -raw resource_group_name
$dnsVm = terraform output -raw dns_vm_name
$blob = terraform output -raw blob_hostname
$expected = terraform output -raw blob_private_ip
az network vpn-connection list -g $rg --query "[].{name:name,status:connectionStatus}" -o table
az vm run-command invoke -g $rg -n $dnsVm --command-id RunPowerShellScript --scripts "Resolve-DnsName $blob -Server 127.0.0.1; Test-NetConnection $expected -Port 443"
terraform output resolver_inbound_ip
terraform output blob_private_ip
```

The explicit query to the local DNS service ultimately returns the Blob private endpoint IP. The TCP test uses the expected private IP explicitly, avoiding the VM's ordinary configured resolver. Compare DNS output with that expected IP; both must describe the same endpoint. DNS success grants no storage data-plane permission.

Save a short local evidence note with the time, exact probe, observed result, and your explanation. Resource existence, DNS, routing, authorization, and application success are different kinds of evidence.

## Verify the corporate direction separately

The corporate Windows DNS VM is authoritative for `corp.tfa.internal`; `files` is an A record at 10.131.2.4. `reverse-dns.tf` creates the outbound subnet 10.31.1.16/28, delegates it to DNS Resolver, links the forwarding ruleset to the Azure VNet and sends only `corp.tfa.internal.` queries to that Windows server. The Azure probe uses normal VNet DNS; the link selects the forwarding rule. Explicit NAT at each site supports VM agent/bootstrap traffic, while private corporate and endpoint traffic follows the VPN.

```powershell
$azureProbe = terraform output -raw azure_probe_vm_name
$corpName = terraform output -raw corporate_hostname
$corpIp = terraform output -raw corporate_expected_ip
az vm run-command invoke -g $rg -n $azureProbe --command-id RunPowerShellScript --scripts "Clear-DnsClientCache; Resolve-DnsName $corpName -Type A"
# Expected A answer: the exact corporate_expected_ip, not just any private address.
az vm run-command invoke -g $rg -n $dnsVm --command-id RunPowerShellScript --scripts "Resolve-DnsName $blob -Server 127.0.0.1 -Type A"
# Expected A answer: the exact blob_private_ip from this root.
```

Compare both outputs with their exact expected addresses and record them separately. To inject one fault, set `enabled=false` only on `azurerm_private_dns_resolver_forwarding_rule.corp`, review/apply, clear the Azure client's cache and repeat the corporate query. Restore true through a reviewed plan and repeat both directions. A cached answer can outlive the rule change; flushing the client cache does not clear every upstream cache, so record TTLs and allow their bounded expiry before diagnosing.

The mocked suite asserts the namespace, target port 53 endpoint, Azure VNet link, delegated outbound subnet and corporate NSG source range. A passing mock is not a captured DNS answer. All resources, including the probe VM and outbound resolver, belong to this root and are removed by its normal cleanup.

## Troubleshooting

Test the tunnel first, then UDP/TCP 53 reachability, the conditional forwarder, Azure zone link, and DNS record. Forwarding only the privatelink suffix can miss the initial public-service name lookup. Do not point an on-premises DNS forwarder directly to Azure's VNet-local `168.63.129.16` address.

## Challenge

From the DNS VM, test TCP 443 directly to the private IP returned by Resolve-DnsName and record both DNS and TCP evidence. Disable only the corporate forwarding rule, observe the corporate-name failure, restore it, and compare with the still-working Blob query in the other direction.

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
Remove-Item Env:TF_VAR_vpn_shared_key -ErrorAction SilentlyContinue
```

A successful destroy and an empty state are the expected result. The cleanup command uses the captured group, including a changed prefix. Soft-deleted vaults and retained logs can outlive their active resource; review the relevant Azure lifecycle and cost settings. Do not commit generated plans or state as evidence.

## Completion criteria

- You can explain why this design produces the observed behavior.
- You captured the required success evidence and investigated the controlled limitation or failure.
- You completed the challenge and five questions.
- You reviewed and completed cleanup, or recorded an explicit owner and deadline for intentionally retained resources.

## Continue learning

[Official documentation](https://learn.microsoft.com/en-us/azure/dns/private-resolver-hybrid-dns) | [Continue to TFA-032](../TFA-032/README.md)

## Evidence contract

From corporate DNS resolve the original Blob name; from Azure probe resolve files.corp.tfa.internal. Blob resolves to its exact private endpoint and the corporate record resolves to 10.131.2.4.

See the [40-lab evidence map](../../docs/curriculum-evidence.md) for source paths, validation level and cleanup dependencies. Authored Azure commands are learner exercises; passing local checks does not establish a live deployment.

The local evidence parser is [Test-DnsEvidence.ps1](Test-DnsEvidence.ps1). Run the shared regression from the repository root: `pwsh -NoProfile -File tests/Test-LessonEvidence.ps1`. Its [synthetic fixtures](../../tests/fixtures/lesson-evidence/README.md) validate response interpretation without Azure access.
