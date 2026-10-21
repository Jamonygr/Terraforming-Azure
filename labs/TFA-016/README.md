# TFA-016 — Azure remote-state bootstrap

<!-- lab-metadata:start -->
**Phase 3:** Terraform engineering

**Learning target:** 75 minutes · **Cost tier:** Low · **Run mode:** `azure`

**Prerequisites:** [TFA-014 — State, addressing, and locking](../TFA-014/README.md), [TFA-015 — Drift, import, and refactoring](../TFA-015/README.md)
<!-- lab-metadata:end -->

<!-- lab-diagram:start -->
![TFA-016 teaching diagram](../../assets/diagrams/TFA-016.svg)
<!-- lab-diagram:end -->

## Goal

Create a small backend from local state, migrate the same resource bindings to Azure Blob state, and migrate back before deleting that backend.

## Workspace and isolation

Earlier cloud labs should already be destroyed; this root deploys independently. Concept prerequisites are listed in the generated catalog block. You also need permission to create Storage accounts and assign the Storage Blob Data Contributor role to your signed-in principal.

## Predict the mechanism

Backend bootstrap begins with local state because storage cannot hold its own state before it exists. Account creation uses ARM without waiting for Blob access; then a scoped data role authorizes the operator. A bounded Blob readiness check must succeed before migrating, and cleanup reverses migration before deleting storage.

Before running commands, write the expected result: **Entra-only storage has recovery protection; migration does not proceed on authorization timeout.** Then explain what would change in this controlled failure: Withhold Blob permission or use a failed-read fixture; retain local state and stop migration. Record your prediction before inspecting the outcome.

## Understand the design

A backend must exist before Terraform can initialize against it. This lab first creates its own storage from local state, then adds an untracked backend block and configuration. Migration copies state ownership; it must not recreate infrastructure. Compare resource addresses and lineage before and after.

The container is private, anonymous blob access is disabled, shared-key authentication is disabled, and the applying identity receives Storage Blob Data Contributor at the account. Role assignment requires the corresponding Azure permission and may take time to propagate. The account still has a public network endpoint for this short exercise; private endpoint and runner network design come later.

## Architecture and resources

Local state → Storage account and tfstate container → Azure Entra authenticated blob backend using tfa016.terraform.tfstate and blob leasing. This isolated exercise is separate from the course’s long-lived ../../bootstrap backend.

See the catalog cost tier above and the [cost and cleanup guide](../../docs/cost-and-cleanup.md). Destroy the lesson when finished and verify its actual resource names.

## Inputs and working directory

Use PowerShell 7 from the repository root, then enter this lesson folder. Copy the example once and edit only the untracked terraform.tfvars. location defaults to westeurope; name_prefix isolates this lesson; tags contains non-secret ownership metadata. subscription_id is required through TF_VAR_subscription_id. Provider auto-registration is disabled: complete TFA-002 readiness checks first.

```powershell
Set-Location labs/TFA-016
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

## Migrate after the first local apply

Do not add a backend block until the Storage account and container exist.
Save the current lineage and addresses before proceeding. These commands write
only untracked runtime files; do not put account keys or credentials in them.

```powershell
$backend = terraform output -json backend_configuration | ConvertFrom-Json
$deadline = (Get-Date).AddMinutes(10)
do {
    az storage container show --auth-mode login --account-name $backend.storage_account_name --name $backend.container_name --only-show-errors -o none
    $ready = $LASTEXITCODE -eq 0
    if (-not $ready -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 15 }
} until ($ready -or (Get-Date) -ge $deadline)
if (-not $ready) { throw 'Blob access is not ready after 10 minutes. Check identity, role scope and network access; keep local state and do not migrate.' }
$backend.PSObject.Properties | ForEach-Object {
    $value = if ($_.Value -is [bool]) { $_.Value.ToString().ToLowerInvariant() } else { '"' + $_.Value + '"' }
    $_.Name + ' = ' + $value
} | Set-Content backend.hcl
Copy-Item backend.tf.example backend.tf
terraform init -migrate-state -backend-config=backend.hcl
if ($LASTEXITCODE -ne 0) { throw 'Migration failed. Retain both state copies and backend settings; investigate before continuing.' }
terraform state list
```

Review the storage account, tenant, subscription, container, and key before
accepting the state-copy prompt. Keep the backend alive until this lab has been
migrated back to local state during cleanup. Do not share this key with any other lab.

## Validate and collect evidence

```powershell
$backend = terraform output -json backend_configuration | ConvertFrom-Json
terraform state list
terraform state pull | ConvertFrom-Json | Select-Object lineage,serial
az storage blob show --auth-mode login --account-name $backend.storage_account_name --container-name $backend.container_name --name $backend.key --query "{name:name,size:properties.contentLength}" -o json
```

**Expected:** After the migration steps above, Azure CLI finds the state blob using login authentication. The same resource addresses and state lineage are present. A subsequent plan has no changes.

For a deployable lesson, finish with terraform plan -detailed-exitcode: 0 means
no changes, 2 means a change exists, and 1 means an error. A mock test checks
configuration behavior; it is not a network connectivity test.

## Exercises

1. Before migration record (terraform state pull | ConvertFrom-Json).lineage and terraform state list. Run the migration, compare them, and explain why provider authentication and backend authentication are separate configurations.
2. Inspect Blob versions in Azure and explain how versioning can support recovery. Never publish state contents or dump secrets while collecting evidence.
3. Explain the diagram and your validation evidence to another learner. Include
   what the evidence does and does not prove, then answer [five review questions](quiz.json).

## Break and repair

If initialization returns 403, inspect tenant/subscription, assigned blob-data role, role propagation, and any storage network restrictions. Retry after permissions propagate. Do not enable shared keys as a shortcut. If Terraform proposes recreating backend objects after migration, stop and compare addresses and lineage.

## Troubleshooting

| Symptom | Investigation |
|---|---|
| Initialization or schema validation fails | Check the working directory, Terraform version, module source paths, and tracked provider lockfile. Run init before validate. |
| Azure returns authorization, quota, or region errors | Verify the explicit subscription and tenant, role scope, registered provider, regional SKU availability, and quota from TFA-002. |
| Results differ from the expected evidence | Compare the actual resource IDs and effective state with this lesson's architecture. Read the service-specific explanation above before changing permissions or network policy. |

## Cleanup and proof

```powershell
# Keep backend.hcl values until migration is complete. Do not destroy remote storage first.
$rg = terraform output -raw resource_group_name
if ($LASTEXITCODE -ne 0 -or -not $rg) { throw 'Capture the exact owned group before destruction.' }
Rename-Item backend.tf backend.tf.remote
terraform init -migrate-state
if ($LASTEXITCODE -ne 0) { throw 'Reverse migration failed. Keep the remote backend and runtime files; do not destroy storage.' }
terraform state list
Remove-Item backend.tf.remote, backend.hcl -ErrorAction SilentlyContinue
terraform destroy
if ($LASTEXITCODE -ne 0) { throw 'Destroy failed: keep state and investigate before continuing.' }
$remaining = @(terraform state list)
if ($LASTEXITCODE -ne 0 -or $remaining.Count) { throw 'Cleanup left managed objects or state could not be read.' }
$groupExists = az group exists --name $rg --subscription $env:TF_VAR_subscription_id
if ($LASTEXITCODE -ne 0 -or $groupExists -ne 'false') { throw 'The owned group is not confirmed deleted. Keep state and investigate.' }
Remove-Item tfplan -ErrorAction SilentlyContinue
```

State should contain no managed resources. Azure CLI should return false for the deleted group (or an empty list for the multi-group lesson).

## Production differences

Production backend ownership must outlive workload states. Use the canonical ../../bootstrap root for the later platform, separate state keys, approved networking and runners, retention/recovery policy, and tested restoration. This exercise deliberately migrates its own state back before cleanup.

## Navigation

[Previous: TFA-015](../TFA-015/README.md) · [Curriculum](../../README.md) · [Next: TFA-017](../TFA-017/README.md)

## Evidence contract

Inspect ARM-only provider behavior and scoped role; follow bounded Blob readiness, migration and migration-back instructions. Entra-only storage has recovery protection; migration does not proceed on authorization timeout.

See the [40-lab evidence map](../../docs/curriculum-evidence.md) for source paths, validation level and cleanup dependencies. Authored Azure commands are learner exercises; passing local checks does not establish a live deployment.
