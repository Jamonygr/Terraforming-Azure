# Capstone evidence and offline test contract

All committed snapshots and provider defaults are synthetic. They contain no
captured Azure success record, real certificate, token or credential.

## Repeatable local commands

From the repository root:

```powershell
terraform -chdir=modules/capstone init -backend=false -lockfile=readonly
terraform -chdir=modules/capstone validate
terraform -chdir=modules/capstone test
terraform -chdir=labs/TFA-040 init -backend=false -lockfile=readonly
terraform -chdir=labs/TFA-040 validate
terraform -chdir=labs/TFA-040 test
pwsh -NoProfile -File labs/TFA-040/tests/Test-InfrastructureBehavior.ps1
python tools/test_capstone_mutations.py
```

Use the pinned Terraform 1.15.8 and contributor Python 3.12+. Provider installation
may need public registry access. Test execution uses mock providers and synthetic
PowerShell adapters; it requires no Azure login or credentials.

## What the tests establish

The module suite exercises cumulative mocked stages, actual NIC/route/subnet
associations, scoped identity roles, Firewall rules, Bastion features, DNS settings
and reciprocal gateway IDs. The root also rejects noncanonical IPv4 CIDRs,
malformed addresses, host bits and `/0` aliases such as `203.0.113.1/0`; canonical
`/32` and network `/24` inputs pass. Resource addresses are unchanged.

The mutation runner requires a clean passing mock baseline, changes one resource
expression in an isolated temporary copy, and requires the intended **assertion**
to fail. An initialization error, parser error or Terraform crash is never counted
as mutation success. It restores the source between the five targeted mutations.
The temporary root is bounded under `Terraforming-Azure-mutation-checks` in the
OS temporary directory; the working repository is not mutated.

The PowerShell behavior suite tests all four stage contracts, missing observations,
malformed responses, duplicate backends/tunnels, public NICs, wrong routes and
DNS, stale telemetry, failed CLI observations and unauthorized data access. It
also checks fixture JSON roundtrips and failure exit codes. Synthetic DNS tests
cover missing/public/wrong-private/mixed answers, delayed exact answers, delayed
RBAC, fatal HTTP failures and token/body redaction. Partial synthetic adapters are
rejected before any real fallback can run.

The local command adapter receives argument arrays as JSON on stdin, launches a
fixed helper file, enforces a process timeout, and suppresses raw stderr. Tests
invoke only local Terraform version reporting and bounded local PowerShell work.
Readiness fixtures verify supported version ranges, provider registration, regional
SKU restrictions and vCPU quota decisions; unresolved permissions/capacity stay
`SKIP`.

## Evidence schema version 1

`New-SyntheticSnapshot.ps1` returns `schema_version`, `evidence_kind`,
`collected_at`, unwrapped Terraform `outputs`, and an `observations` map. The pure
`Test-CapstoneSnapshot` function reads that map without performing any I/O.

Each result has an ID, stage, target, status, source and observation timestamp.
`PASS` means supplied fields satisfy that one predicate. `FAIL` means a field
contradicts the contract, is malformed, or collection failed. `SKIP` means no
observation exists. Fixture reports retain `evidence_kind = synthetic` and always
set `azure_runtime_certified = false`; there is no synthetic-to-runtime promotion.

`Test-Capstone.ps1` defaults to fixture mode and requires `-FixturePath`.
`-Mode AzureReadOnly` explicitly opts into the authored collector, whose commands
are bounded. `-SkipPublicIngress` skips its two public HTTPS requests. The collector
never infers guest identity, DNS, logs, inspection, alert recovery or cross-tunnel
HTTP success from control-plane health; those observations remain absent/`SKIP`.
This adapter has not been executed against Azure as part of the offline overhaul.

Live API response compatibility, quotas, permission propagation, gateway traffic,
WAF behavior, managed-identity data access, monitoring, recovery, repeat-plan
stability and complete teardown remain unverified until an authorized live run.
