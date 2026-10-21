# Bootstrap the course backend

This root owns only the remote-state resource group, Storage account, private
container, and backend role assignment. It begins with local state. The capstone
uses a different key and does not own this backend.

The account has a public network endpoint for workstation and GitHub-hosted runner
access, but anonymous container access and shared keys are disabled. Authenticate
with Entra ID. This deliberate backend networking exception is separate from the
capstone's private workload Storage account.

## Prerequisites

Complete TFA-002 and TFA-016. Use a disposable training subscription. The bootstrap
operator needs resource creation and role assignment permissions at the selected
scope. Storage RBAC can take several minutes to propagate. Resource provider
registration is deliberate: check and, if necessary, register `Microsoft.Storage`
and other required providers before deploying. The provider never automatically
registers the entire subscription.

```powershell
Set-Location bootstrap
$env:TF_VAR_subscription_id = az account show --query id --output tsv
terraform init -lockfile=readonly
terraform plan -out tfplan
terraform show tfplan
terraform apply tfplan
$stateAccount = terraform output -raw storage_account_name
$stateGroup = terraform output -raw resource_group_name
$stateTenant = terraform output -raw tenant_id
$env:ARM_USE_AZUREAD = 'true'
```

## Migrate bootstrap state

Make a protected local backup first. Then add the backend declaration and migrate:

```powershell
Copy-Item terraform.tfstate terraform.tfstate.before-migration
Copy-Item backend.remote.tf.example backend.remote.tf
terraform init -migrate-state `
  -backend-config="storage_account_name=$stateAccount" `
  -backend-config='container_name=tfstate' `
  -backend-config='key=bootstrap.terraform.tfstate' `
  -backend-config='use_azuread_auth=true'
terraform state list
terraform plan
```

Expected: four managed resource addresses (five when an additional OIDC principal
was supplied) plus the client-config data source;
the post-migration plan reports no changes. Confirm the state blob exists using
`az storage blob list --account-name $stateAccount --container-name tfstate
--auth-mode login --output table`. Protect and eventually remove local backups.

Initialize TFA-040 using the same account and container with
`key=capstone.terraform.tfstate`. Every independent exercise using this backend
must have its own key. Backend settings cannot refer to Terraform input variables.

## Recovery and cleanup order

1. Destroy the capstone and every exercise using this account.
2. Return here and back up the remote bootstrap state to a protected local path.
3. Remove only the ignored backend declaration, then migrate back to local state.
4. Review and apply a bootstrap destroy plan.

```powershell
terraform state pull | Set-Content -LiteralPath bootstrap-state.backup.json
Remove-Item -LiteralPath ./backend.remote.tf
terraform init -migrate-state
terraform plan -destroy -out tfplan
terraform show tfplan
terraform apply tfplan
az group exists --name $stateGroup
```

Expected final answer: `false`. Do not destroy the backend while it still holds
the only state Terraform needs to update. State snapshots contain sensitive data;
`bootstrap-state.backup.json` must never be committed.
