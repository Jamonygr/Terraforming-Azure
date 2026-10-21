# TFA-009 — Explicit outbound connectivity

![Explicit outbound connectivity teaching diagram](../../assets/diagrams/TFA-009.svg)

## Goal

Connect a private subnet to an explicit NAT Gateway and distinguish outbound SNAT from inbound publication.

## Prerequisites

Complete [TFA-008](../TFA-008/README.md). Earlier cloud labs should already be destroyed; this root deploys independently.

## Understand the design

A private IP has no direct Internet return path. NAT Gateway translates outbound flows to a stable public source address and tracks their return traffic. It does not create an inbound listener or permit unsolicited inbound connections.

The subnet disables default outbound access and explicitly associates a Standard NAT Gateway and Standard static public IP. There is no VM here; the goal is to inspect a complete egress path before depending on it during the Windows bootstrap in TFA-010.

## Architecture and resources

Private workload subnet → NAT Gateway → Standard static public IPv4 → Internet destination. Replies return through the NAT mapping; no public IP is attached to a workload NIC.

**Cost:** Moderate: NAT Gateway, its public IPv4 address, and processed data are billable. Destroy the lesson when finished. A stopped VM may still have billable disks; deleting all lab resources is the cleanup target.

## Inputs and working directory

Use PowerShell 7 from the repository root, then enter this lesson folder. Copy the example once and edit only the untracked terraform.tfvars. location defaults to westeurope; name_prefix isolates this lesson; tags contains non-secret ownership metadata. subscription_id is required through TF_VAR_subscription_id. Provider auto-registration is disabled: complete TFA-002 readiness checks first.

```powershell
Set-Location labs/TFA-009
```

## Build and inspect

Read main.tf before running the commands. Review the proposed actions and
subscription before approving an apply. An existing tfvars file should be edited,
not overwritten; skip Copy-Item when you already have one.

```powershell
az login
az account list --output table
az account set --subscription '<your-subscription-guid>'
$env:TF_VAR_subscription_id = az account show --query id --output tsv
az account show --query '{tenant:tenantId,subscription:id,user:user.name}' --output table
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -backend=false -input=false -lockfile=readonly
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

Never commit terraform.tfvars, backend runtime files, saved plans, state, crash
logs, or secret-bearing command output. Keep dependency lockfiles in source control.

## Validate and collect evidence

```powershell
$rg = terraform output -raw resource_group_name
az network nat gateway list -g $rg --query "[].{name:name,state:provisioningState,ips:publicIpAddresses[].id}" -o json
az network vnet subnet show --ids (terraform output -raw subnet_id) --query "{nat:natGateway.id,defaultOutbound:defaultOutboundAccess}" -o json
terraform output -raw outbound_public_ip
```

**Expected:** The NAT Gateway is Succeeded with a public IP association. The workload subnet points to that gateway and defaultOutboundAccess is false. No traffic test is claimed until a workload exists.

For a deployable lesson, finish with terraform plan -detailed-exitcode: 0 means
no changes, 2 means a change exists, and 1 means an error. A mock test checks
configuration behavior; it is not a network connectivity test.

## Exercises

1. Draw the source and destination addresses before and after outbound SNAT, then describe why that public IP cannot be used for an inbound RDP connection.
2. Inspect dependencies in terraform graph. Explain why a subnet association and public IP association must both exist before a VM bootstrap depends on working outbound access.
3. Explain the diagram and your validation evidence to another learner. Include
   what the evidence does and does not prove, then answer [five review questions](quiz.json).

## Break and repair

Comment out the subnet association and plan. Expect removal of the egress attachment while the NAT resource remains. Do not apply the broken design; restore it and confirm no change. In TFA-010 use a workload test to prove the actual source address.

## Troubleshooting

| Symptom | Investigation |
|---|---|
| Initialization or schema validation fails | Check the working directory, Terraform version, module source paths, and tracked provider lockfile. Run init before validate. |
| Azure returns authorization, quota, or region errors | Verify the explicit subscription and tenant, role scope, registered provider, regional SKU availability, and quota from TFA-002. |
| Results differ from the expected evidence | Compare the actual resource IDs and effective state with this lesson's architecture. Read the service-specific explanation above before changing permissions or network policy. |

## Cleanup and proof

```powershell
$rg = terraform output -raw resource_group_name
terraform destroy
terraform state list
az group exists --name $rg --subscription $env:TF_VAR_subscription_id
Remove-Item tfplan -ErrorAction SilentlyContinue
```

State should contain no managed resources. Azure CLI should return false for the deleted group (or an empty list for the multi-group lesson).

## Production differences

Choose egress deliberately for policy, routing, resilience, scale, and cost. NAT alone provides translation; it does not enforce the application filtering later introduced by Azure Firewall.

## Navigation

[Previous: TFA-008](../TFA-008/README.md) · [Curriculum](../../README.md) · [Next: TFA-010](../TFA-010/README.md)
