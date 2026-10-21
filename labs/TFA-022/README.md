# TFA-022 - Azure DNS and private DNS

[Course home](../../README.md) | [Previous lab](../TFA-021/README.md) | [Next lab](../TFA-023/README.md)

> **Mode:** Azure deployment | **Time:** 50-70 minutes | **Cost:** Low: public/private DNS zones and queries.

## Why this lab exists

A network can route correctly while an application still fails because it resolves the wrong address. This lab separates DNS records, delegation, VNet links, and actual reachability.

## What you will learn

By the end, explain the mechanism below, follow its dependencies in Terraform, reproduce its evidence, diagnose the named failure, and clean up the resources you created. The final challenge checks whether you can apply the concept without copying another resource block.

## Concepts before commands

Azure DNS hosts an authoritative public zone. Creating that zone does not delegate a name to it: the parent zone must publish its name servers. The public `tfa022.example.com` zone and `192.0.2.10` documentation address deliberately demonstrate records without claiming ownership of example.com. A private zone is visible through linked VNets. A DNS record does not create the server at its address.

## Architecture

![TFA-022 architecture](../../assets/diagrams/TFA-022.svg)

One VNet, a public demonstration zone and A record, a private `.test` zone, an explicit VNet link, and a private A record.

## Prerequisites and cost checkpoint

PowerShell 7, Terraform 1.9 or later (under 2.0; course tested with 1.15.8), Git, and the preceding concepts. Azure CLI, an explicitly selected sandbox subscription, approved permissions and regional quota. AzureRM is pinned to 4.77.0; do not silently upgrade it during the lesson.

Low: public/private DNS zones and queries. Read the selected services in the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/) before apply. A stopped VM can retain charged disks; a gateway/firewall is not stopped by leaving the terminal. Each lab owns its own local state; keep that state until cleanup. Do not reuse another lab's backend or import its resources.

## Step 1 - Read the implementation

Open `versions.tf`, `variables.tf`, `main.tf`, and `outputs.tf` in this directory. Follow `azurerm_dns_zone.public` -> `azurerm_dns_a_record.public`, then `azurerm_private_dns_zone.internal` -> its link and record. Compare TTLs and explain why registration is disabled. If a shared Windows VM pattern is referenced, read its [implementation](../../modules/patterns/windows-vm/main.tf) as part of this lesson.

## Step 2 - Plan and build

Run from `labs/TFA-022` in PowerShell 7. Tests use provider mocks or local resources and do not apply Azure infrastructure. Supply real cloud inputs only for your deliberate plan/apply. The example tfvars file is an alternative to environment variables; a real terraform.tfvars value takes precedence over TF_VAR values.

```powershell
$env:TF_VAR_subscription_id = Read-Host 'Explicit Azure subscription ID'
az login
az account set --subscription $env:TF_VAR_subscription_id
$env:TF_VAR_location = 'westeurope'
terraform init
terraform fmt -check
terraform validate
terraform test
terraform plan -out=lab.tfplan
terraform show lab.tfplan
# Read the whole plan and confirm the subscription, scope, and charged services.
terraform apply lab.tfplan
```

Record what Terraform creates, which values are unknown until apply, and which resources carry ongoing charges. Keep passwords, VPN keys, PFX files, plans, and state out of Git. `sensitive` hides console values; it does not remove them from state.

## Step 3 - Verify with evidence

```powershell
$rg = terraform output -raw resource_group_name
az network dns record-set a show -g $rg -z tfa022.example.com -n demo
az network private-dns record-set a show -g $rg -z internal.terraforming-azure.test -n app
az network private-dns link vnet list -g $rg -z internal.terraforming-azure.test -o table
$ns = (terraform output -json authoritative_name_servers | ConvertFrom-Json)[0]
Resolve-DnsName demo.tfa022.example.com -Server $ns
```

The authoritative public server answers `192.0.2.10`, even though ordinary recursive lookup has no delegated path to this demonstration zone. Azure lists the private record `10.22.1.10` and its VNet link. Your laptop is outside that linked VNet; do not interpret a laptop private-name lookup failure as a missing Azure record.

Save a short local evidence note with the time, exact probe, observed result, and your explanation. Resource existence, DNS, routing, authorization, and application success are different kinds of evidence.

## Troubleshooting

If a private query fails, check its client VNet, the zone link, the resolver it uses, and its cached TTL. If public lookup fails, distinguish querying the authoritative name server directly from following public delegation.

## Challenge

Change the private A record to `10.22.1.20`, reduce its TTL to 30, review the plan, and apply. Explain why neither action provisions a VM.

## Knowledge check

Complete the five questions in [quiz.json](quiz.json), or use the course site's interactive quiz. Explain each answer before revealing its explanation. The quiz checks reasoning; it is not a substitute for the evidence above.

## Cleanup

```powershell
terraform plan -destroy -out=cleanup.tfplan
terraform show cleanup.tfplan
terraform apply cleanup.tfplan
terraform state list
# Check the Azure resource group no longer exists after successful destroy.
az group exists --subscription $env:TF_VAR_subscription_id --name rg-tfa022
```

A successful destroy and an empty state are the expected result. Verify the actual lab group name from the earlier output if you changed name_prefix. Soft-deleted vaults and retained logs can outlive their active resource; review the relevant Azure lifecycle and cost settings. Do not commit generated plans or state as evidence.

## Completion criteria

- You can explain why this design produces the observed behavior.
- You captured the required success evidence and investigated the controlled limitation or failure.
- You completed the challenge and five questions.
- You reviewed and completed cleanup, or recorded an explicit owner and deadline for intentionally retained resources.

## Continue learning

[Official documentation](https://learn.microsoft.com/en-us/azure/dns/private-dns-overview) | [Continue to TFA-023](../TFA-023/README.md)
