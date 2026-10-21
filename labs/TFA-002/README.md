# TFA-002 — Prepare your workstation and subscription

![Prepare your workstation and subscription teaching diagram](../../assets/diagrams/TFA-002.svg)

## Goal

Collect tool, identity, subscription, provider, quota, and cost evidence before the first billable deployment.

## Prerequisites

Complete [TFA-001](../TFA-001/README.md). Earlier cloud labs should already be destroyed; this root deploys independently.

## Understand the design

Authentication answers who you are; authorization answers what you may do. A successful az login does not prove you can create a VM or assign a role. Subscription selection is equally important: display names can be duplicated, so record and pass the GUID.

The Terraform example is a local checklist. Its default output lists every incomplete check. Setting a boolean records your own evidence; it does not make an Azure API call or verify a permission. Keep the distinction visible when sharing screenshots or progress records.

## Architecture and resources

Read-only Azure CLI checks supply human-reviewed evidence. Terraform evaluates a local readiness object; no resource or backend is created.

**Cost:** None Destroy the lesson when finished. A stopped VM may still have billable disks; deleting all lab resources is the cleanup target.

## Inputs and working directory

Use PowerShell 7 from the repository root, then enter this lesson folder. Copy the example once and edit only the untracked terraform.tfvars. Use only the lesson-specific inputs shown in main.tf and the example file. This local model does not require Azure authentication.

```powershell
Set-Location labs/TFA-002
```

## Build and inspect

Read main.tf before running the commands. Review the proposed actions and
subscription before approving an apply. An existing tfvars file should be edited,
not overwritten; skip Copy-Item when you already have one.

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -backend=false -input=false
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
pwsh --version
terraform version
az version
git --version
az account show --query "{tenant:tenantId,subscription:id,user:user.name}" -o table
az provider show --namespace Microsoft.Network --query registrationState -o tsv
az provider show --namespace Microsoft.Compute --query registrationState -o tsv
az provider show --namespace Microsoft.Storage --query registrationState -o tsv
az vm list-usage --location westeurope -o table
terraform output -json readiness
```

**Expected:** Record the exact subscription and tenant. Network, Compute, and Storage must be Registered before the relevant deployment. Review regional vCPU/SKU quotas and the subscription budget in Azure Cost Management. Default checklist output is ready=false; it becomes true only after you record all six completed checks and apply the local output state.

For a deployable lesson, finish with terraform plan -detailed-exitcode: 0 means
no changes, 2 means a change exists, and 1 means an error. A mock test checks
configuration behavior; it is not a network connectivity test.

## Exercises

1. Run az account list --output table, select your intended account with az account set --subscription <GUID>, and compare az account show. The GUID must match your intended subscription.
2. Add checks = { tools=true, identity=true, subscription=true, providers=true, quota=true, budget=true } to your untracked tfvars only after collecting evidence. The local plan changes ready from false to true.
3. Explain the diagram and your validation evidence to another learner. Include
   what the evidence does and does not prove, then answer [five review questions](quiz.json).

## Break and repair

Set checks.providers=false and inspect the plan. Readiness must become false and incomplete must contain providers. Repair the actual Azure prerequisite separately, then record the check as true. A subscription administrator may need to register a provider; this lesson does not register providers automatically.

## Troubleshooting

| Symptom | Investigation |
|---|---|
| Initialization or schema validation fails | Check the working directory, Terraform version, module source paths, and tracked provider lockfile. Run init before validate. |
| Azure returns authorization, quota, or region errors | Verify the explicit subscription and tenant, role scope, registered provider, regional SKU availability, and quota from TFA-002. |
| Results differ from the expected evidence | Compare the actual resource IDs and effective state with this lesson's architecture. Read the service-specific explanation above before changing permissions or network policy. |

## Cleanup and proof

```powershell
terraform destroy
terraform state list
Remove-Item tfplan -ErrorAction SilentlyContinue
```

No Azure resource exists in this workflow. Managed local resources, when present, must be absent from state after cleanup.

## Production differences

Team readiness also includes least-privilege access, deployment identity ownership, approved regions/SKUs, policy constraints, support ownership, and cost alerts. Use organization-specific gates before production.

## Navigation

[Previous: TFA-001](../TFA-001/README.md) · [Curriculum](../../README.md) · [Next: TFA-003](../TFA-003/README.md)
