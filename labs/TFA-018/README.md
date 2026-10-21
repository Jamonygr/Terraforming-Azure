# TFA-018 — Module contracts and safe changes

<!-- lab-metadata:start -->
**Phase 3:** Terraform engineering

**Learning target:** 75 minutes · **Cost tier:** Low · **Run mode:** `azure`

**Prerequisites:** [TFA-017 — Your first reusable module](../TFA-017/README.md)
<!-- lab-metadata:end -->

<!-- lab-diagram:start -->
![TFA-018 teaching diagram](../../assets/diagrams/TFA-018.svg)
<!-- lab-diagram:end -->

## Goal

Treat typed inputs, output keys, and resource addresses as a contract and distinguish additive changes from replacements.

## Workspace and isolation

Earlier cloud labs should already be destroyed; this root deploys independently. Concept prerequisites are listed in the generated catalog block.

## Predict the mechanism

Validation checks the contract domain, while lifecycle behavior controls how Terraform responds to change. A typed input can still be operationally unsafe if it allows overlapping networks or names that force replacement. A useful output describes a stable capability, such as a subnet ID, rather than an internal implementation detail.

Before running commands, write the expected result: **Invalid inputs fail early; replacement-producing changes are visible before apply.** Then explain what would change in this controlled failure: Supply an invalid module input and repair the contract or caller deliberately. Record your prediction before inspecting the outcome.

## Understand the design

A module’s contract includes more than variable types. Callers may rely on output names and keys, resource naming behavior, and migration compatibility. Adding a new subnet key is normally additive. Renaming an existing key changes its Terraform address even if a person thinks of it as the same subnet.

The module validates CIDR syntax and nonempty input maps. It intentionally does not implement full CIDR containment and overlap checking. Azure still validates those dynamic network constraints. Document the limit instead of implying terraform validate proves the complete address plan.

## Architecture and resources

The same learning-network module now accepts a caller-supplied subnets map for 10.18.0.0/16. web and app are stable identities; new keys can be added without changing them.

See the catalog cost tier above and the [cost and cleanup guide](../../docs/cost-and-cleanup.md). Destroy the lesson when finished and verify its actual resource names.

## Inputs and working directory

Use PowerShell 7 from the repository root, then enter this lesson folder. Copy the example once and edit only the untracked terraform.tfvars. location defaults to westeurope; name_prefix isolates this lesson; tags contains non-secret ownership metadata. subscription_id is required through TF_VAR_subscription_id. Provider auto-registration is disabled: complete TFA-002 readiness checks first.

```powershell
Set-Location labs/TFA-018
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
terraform output -json subnet_ids
terraform state list
terraform plan -detailed-exitcode
```

**Expected:** The initial subnet output contains web and app. Adding data=10.18.3.0/24 must propose one subnet creation while retaining existing keyed addresses.

For a deployable lesson, finish with terraform plan -detailed-exitcode: 0 means
no changes, 2 means a change exists, and 1 means an error. A mock test checks
configuration behavior; it is not a network connectivity test.

## Exercises

1. Set subnets={web="10.18.1.0/24",app="10.18.2.0/24",data="10.18.3.0/24"} in tfvars. Review and apply the additive plan, then confirm all three keys.
2. Plan a web-to-frontend key rename. Do not apply: identify destroy/create actions and explain why a reviewed moved block plus Azure name compatibility is needed for an address migration.
3. Explain the diagram and your validation evidence to another learner. Include
   what the evidence does and does not prove, then answer [five review questions](quiz.json).

## Break and repair

Supply subnets={} or a value such as "not-a-cidr" and plan. Validation must fail before cloud changes. Repair the map. For a syntactically valid but overlapping CIDR, recognize that this module still relies on Azure validation.

## Troubleshooting

| Symptom | Investigation |
|---|---|
| Initialization or schema validation fails | Check the working directory, Terraform version, module source paths, and tracked provider lockfile. Run init before validate. |
| Azure returns authorization, quota, or region errors | Verify the explicit subscription and tenant, role scope, registered provider, regional SKU availability, and quota from TFA-002. |
| Results differ from the expected evidence | Compare the actual resource IDs and effective state with this lesson's architecture. Read the service-specific explanation above before changing permissions or network policy. |

## Cleanup and proof

```powershell
$rg = terraform output -raw resource_group_name
if ($LASTEXITCODE -ne 0 -or -not $rg) { throw 'Capture the exact owned group before destruction.' }
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

Publish breaking interface or naming changes as explicit releases with upgrade notes and migrations. Test both expected behavior and rejected inputs, and inspect real plans for replacements before upgrading a shared module.

## Navigation

[Previous: TFA-017](../TFA-017/README.md) · [Curriculum](../../README.md) · [Next: TFA-019](../TFA-019/README.md)

## Evidence contract

Run the module contract tests and inspect a deliberate invalid-input or replacement plan. Invalid inputs fail early; replacement-producing changes are visible before apply.

See the [40-lab evidence map](../../docs/curriculum-evidence.md) for source paths, validation level and cleanup dependencies. Authored Azure commands are learner exercises; passing local checks does not establish a live deployment.

Run `terraform test` after initialization for three mocked interface contracts: stable subnet keys, empty-map rejection and malformed-CIDR rejection. The key-renaming/replacement exercise remains an authored plan review; it is not a simulated Azure lifecycle or a resource replacement observed during this overhaul.
