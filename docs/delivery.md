# GitHub delivery and OIDC

Pull-request quality checks need no Azure credentials. The learning website
publishes from `main` only after those checks pass. Live infrastructure changes
are available only through the manually invoked `Azure course lifecycle`
workflow; the course does not enable it with real account values automatically.

## Configure the trust boundary

Complete TFA-036 and bootstrap the backend first. Create a user-assigned managed
identity and federated credentials scoped to this exact repository's environments
`azure-plan` and `azure-course`. Give it only the required training-resource scopes
plus Blob Data Contributor on the backend container. Capstone role assignments
also require narrowly scoped role-assignment permission; plain Contributor alone
does not include that permission. Document any subscription-level role required
to create a dedicated lab resource group, then remove it after the lab.

In GitHub Settings → Environments, create `azure-plan` and `azure-course`. Restrict
deployment branches to `main`. Configure a required reviewer for `azure-course`
and review the fresh plan before approval. Merely naming an environment does not
configure its protection rules. A solo learner must select a protection arrangement
that their GitHub account supports; the workflow is still manually dispatched.

## Repository/environment configuration

| Variable | Value |
|---|---|
| `AZURE_CLIENT_ID` | Federated managed identity client ID |
| `AZURE_TENANT_ID` | Entra tenant UUID |
| `AZURE_SUBSCRIPTION_ID` | Explicit disposable subscription UUID |
| `TFSTATE_ACCOUNT` | Bootstrap Storage account name |
| `NAME_PREFIX` | 3–12 lowercase alphanumeric prefix, default `tfazure` |
| `AZURE_LOCATION` | Verified region, default `westeurope` |
| `OPERATOR_CIDRS` | JSON array of specific public CIDRs; no world-open `/0` |

| Secret | Purpose |
|---|---|
| `LAB_ADMIN_PASSWORD` | Windows training password; use a strong unique value |
| `LAB_CERTIFICATE_PFX` | Base64 of the ignored self-signed training PFX |
| `LAB_CERTIFICATE_PASSWORD` | PFX password |
| `LAB_VPN_SHARED_KEY` | Unique IPsec key for the hybrid stage |
| `PLAN_ENCRYPTION_KEY` | Strong independent passphrase for encrypted plan artifacts |

OIDC removes a stored Azure application client secret. It does not eliminate the
Windows, certificate, VPN or artifact-encryption secrets needed for this lab.
The workflow never prints them. Set GitHub secrets through a secure local input
path; do not paste values into tracked examples or issue comments.

## Run a reviewed change

From the Actions tab, dispatch the lifecycle workflow against `main`, choose
`plan`, `apply`, or `destroy`, and choose the cumulative stage. Each dispatch
creates a fresh plan against the current backend. `plan` stops after producing
review evidence. `apply` and `destroy` wait at the `azure-course` environment
before applying the exact plan from the same run.

The artifact includes commit, stage, operation, creation time and plan digest.
The binary plan is encrypted using GPG AES256 before upload because a public
repository's artifacts are not a safe place for a plaintext plan containing
passwords. The apply job decrypts it, verifies its digest, checks the commit and
stage, and rejects a plan older than 24 hours. Retention is one day. Review
Terraform's redacted human-readable output in the plan job before approval.

The workflow serializes all capstone operations. A stale-plan failure requires
a new plan and review. Do not bypass locking or silently regenerate a plan in
the apply job. Bootstrap creation/destruction remains a deliberate local action
because it owns the state service used by this workflow.

## Cleanup

Dispatch `destroy` with the current stage, inspect the destruction plan, approve
the protected job, and verify resources are gone. Retain the backend until all
consumers are destroyed. Remove the OIDC role assignments and federation when
the training repository no longer needs Azure access.
