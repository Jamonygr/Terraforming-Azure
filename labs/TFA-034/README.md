# TFA-034 - Network incident investigation

[Course home](../../README.md) | [Previous lab](../TFA-033/README.md) | [Next lab](../TFA-035/README.md)

> **Mode:** Azure deployment | **Time:** 70-100 minutes | **Cost:** Medium: two private Windows VMs. No Firewall or gateway is deployed in this focused incident lab.

## Why this lab exists

Troubleshooting should produce a falsifiable explanation supported by evidence, then a small reviewed fix.

## What you will learn

By the end, explain the mechanism below, follow its dependencies in Terraform, reproduce its evidence, diagnose the named failure, and clean up the resources you created. The final challenge checks whether you can apply the concept without copying another resource block.

## Concepts before commands

The controlled `incident` switch changes one NSG rule from Allow to Deny. It does not change IIS, addresses, or routes. Start with healthy evidence, inject the fault in Terraform, collect the failing TCP result and effective NSG evidence, and restore the healthy configuration. Keep control-plane reachability, packet transport, and HTTP behavior separate.

## Architecture

![TFA-034 architecture](../../assets/diagrams/TFA-034.svg)

Client/server subnets, two private VMs, IIS on the server, and a subnet NSG with one controlled HTTP rule.

## Prerequisites and cost checkpoint

PowerShell 7, Terraform 1.9 or later (under 2.0; course tested with 1.15.8), Git, and the preceding concepts. Azure CLI, an explicitly selected sandbox subscription, approved permissions and regional quota. AzureRM is pinned to 4.77.0; do not silently upgrade it during the lesson.

Medium: two private Windows VMs. No Firewall or gateway is deployed in this focused incident lab. Read the selected services in the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/) before apply. A stopped VM can retain charged disks; a gateway/firewall is not stopped by leaving the terminal. Each lab owns its own local state; keep that state until cleanup. Do not reuse another lab's backend or import its resources.

## Step 1 - Read the implementation

Open `versions.tf`, `variables.tf`, `main.tf`, and `outputs.tf` in this directory. Follow `var.incident` into the NSG access property. Read the Windows VM module and the server bootstrap command. There is no public RDP ingress and no architecture change needed to repair the intended fault. If a shared Windows VM pattern is referenced, read its [implementation](../../modules/patterns/windows-vm/main.tf) as part of this lesson.

## Step 2 - Plan and build

Run from `labs/TFA-034` in PowerShell 7. Tests use provider mocks or local resources and do not apply Azure infrastructure. Supply real cloud inputs only for your deliberate plan/apply. The example tfvars file is an alternative to environment variables; a real terraform.tfvars value takes precedence over TF_VAR values.

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
$client = terraform output -raw client_vm_name
$serverIp = terraform output -raw server_private_ip
az vm run-command invoke -g $rg -n $client --command-id RunPowerShellScript --scripts "Test-NetConnection $serverIp -Port 80; (Invoke-WebRequest http://$serverIp -UseBasicParsing).StatusCode"
$nic = Split-Path (terraform output -raw server_nic_id) -Leaf
az network nic list-effective-nsg -g $rg -n $nic -o json
terraform plan -var='incident=nsg-block' -out=incident.tfplan
terraform apply incident.tfplan
az vm run-command invoke -g $rg -n $client --command-id RunPowerShellScript --scripts "Test-NetConnection $serverIp -Port 80"
```

The healthy baseline returns TcpTestSucceeded true and HTTP 200. The controlled incident makes TCP fail while the VM still exists and Run Command remains available. The effective rule identifies the deny. Restore `incident=healthy` through a reviewed plan before cleanup.

Save a short local evidence note with the time, exact probe, observed result, and your explanation. Resource existence, DNS, routing, authorization, and application success are different kinds of evidence.

## Troubleshooting

If the healthy baseline already fails, do not inject the next fault. Check IIS service, guest firewall, effective NSG, IP, and routes in that order. Preserve timestamps and outputs in a local incident record; redact subscription identifiers before sharing publicly.

## Challenge

Write a five-line incident report: symptom, impact, hypothesis, decisive evidence, and code fix. Restore healthy, rerun the same probe, and include the before/after difference.

## Knowledge check

Complete the five questions in [quiz.json](quiz.json), or use the course site's interactive quiz. Explain each answer before revealing its explanation. The quiz checks reasoning; it is not a substitute for the evidence above.

## Cleanup

```powershell
terraform plan -destroy -out=cleanup.tfplan
terraform show cleanup.tfplan
terraform apply cleanup.tfplan
terraform state list
# Check the Azure resource group no longer exists after successful destroy.
az group exists --subscription $env:TF_VAR_subscription_id --name rg-tfa034
Remove-Item Env:TF_VAR_admin_password -ErrorAction SilentlyContinue
```

A successful destroy and an empty state are the expected result. Verify the actual lab group name from the earlier output if you changed name_prefix. Soft-deleted vaults and retained logs can outlive their active resource; review the relevant Azure lifecycle and cost settings. Do not commit generated plans or state as evidence.

## Completion criteria

- You can explain why this design produces the observed behavior.
- You captured the required success evidence and investigated the controlled limitation or failure.
- You completed the challenge and five questions.
- You reviewed and completed cleanup, or recorded an explicit owner and deadline for intentionally retained resources.

## Continue learning

[Official documentation](https://learn.microsoft.com/en-us/azure/virtual-network/diagnose-network-traffic-filter-problem) | [Continue to TFA-035](../TFA-035/README.md)
