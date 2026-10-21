# Curriculum outcome and evidence map

This map covers all 40 labs. Source, static, mock, local rehearsal and fixture evidence are different levels. **No Azure login, token exchange, authenticated readiness request or deployment was run during this overhaul.** The probes below describe what a learner would collect during an intentional exercise; they are not a report of successful cloud execution. The machine-readable [catalog](../curriculum/labs.json) owns order, prerequisites, cost and duration; [evidence.json](../curriculum/evidence.json) owns these contracts.

Prerequisites are conceptual unless a cleanup dependency says otherwise. TFA-001 starts with explanation; its optional local preview follows workstation installation in TFA-002. TFA-008/TFA-012 default to configuration inspection and offer explicitly priced probes after TFA-010. The 40-lab duration remains 61 hours 15 minutes; installation delays, Azure provisioning/ingestion and optional packet exercises can extend this, so 60–80 hours is a planning target rather than a timed benchmark. [Cost estimates](cost-and-cleanup.md) come from the dated catalog snapshot.

## TFA-001 — Azure, infrastructure as code, and Terraform

**Outcome:** Explain Azure hierarchy, desired state, providers, and the Terraform resource graph.

**Source:** [README.md](../labs/TFA-001/README.md), [main.tf](../labs/TFA-001/main.tf), [versions.tf](../labs/TFA-001/versions.tf)

**Probe and expected result:** Inspect the local terraform_data output and explain which hierarchy fields are labels, then change one input and read its plan. The plan changes the recorded input; no Azure resource is created.

**Failure and repair:** Change an input and explain an update versus deleting state.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-002 — Prepare your workstation and subscription

**Outcome:** Verify your tools, tenant, subscription, permissions, quota, and regional availability.

**Source:** [README.md](../labs/TFA-002/README.md), [main.tf](../labs/TFA-002/main.tf), [versions.tf](../labs/TFA-002/versions.tf)

**Probe and expected result:** ./scripts/Test-AzureReadiness.ps1 -Mode Local; inspect Get-Command terraform -All and each version. Local checks identify exact supported tools; cloud permission/quota checks remain unresolved.

**Failure and repair:** Use a fixture with a missing tool or a mismatched version; repair the installed path.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-003 — Your first Azure deployment

**Outcome:** Create, change, inspect, and destroy a resource group through a reviewed plan.

**Source:** [README.md](../labs/TFA-003/README.md), [main.tf](../labs/TFA-003/main.tf), [versions.tf](../labs/TFA-003/versions.tf)

**Probe and expected result:** terraform plan -out=lab.tfplan; terraform show lab.tfplan; terraform state list. One resource group address is tracked after apply; repeat plan is empty.

**Failure and repair:** Change a mutable tag, compare the plan, then restore it.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-004 — Variables, types, and validation

**Outcome:** Reject invalid inputs and explain variable precedence before changing resources.

**Source:** [README.md](../labs/TFA-004/README.md), [main.tf](../labs/TFA-004/main.tf), [versions.tf](../labs/TFA-004/versions.tf)

**Probe and expected result:** Plan with valid inputs, then supply an invalid environment and read the variable error. Invalid inputs fail before resource creation; explicit variable precedence is visible.

**Failure and repair:** Set a value of the wrong type or outside the allowed values, then restore it.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-005 — References, locals, data sources, and outputs

**Outcome:** Use references and data sources to compose names, tags, dependencies, and outputs.

**Source:** [README.md](../labs/TFA-005/README.md), [main.tf](../labs/TFA-005/main.tf), [versions.tf](../labs/TFA-005/versions.tf)

**Probe and expected result:** Read the derived name/tags output and compare the resource references with Terraform graph. Derived names agree and the data source is not destroyed by this root.

**Failure and repair:** Change a source naming input and predict every derived name affected.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-006 — Collections and resource identity

**Outcome:** Choose stable resource addresses using collection types, count, and for_each.

**Source:** [README.md](../labs/TFA-006/README.md), [main.tf](../labs/TFA-006/main.tf), [versions.tf](../labs/TFA-006/versions.tf)

**Probe and expected result:** Compare plans after removing a list member and a map key; inspect terraform state list. The keyed instance addresses preserve unaffected identities.

**Failure and repair:** Rename a key and predict destroy/create before introducing moved blocks later.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-007 — IP addressing, CIDR, VNets, and subnets

**Outcome:** Design non-overlapping network ranges and allocate explicit subnets.

**Source:** [README.md](../labs/TFA-007/README.md), [main.tf](../labs/TFA-007/main.tf), [versions.tf](../labs/TFA-007/versions.tf)

**Probe and expected result:** Compare network/subnet prefixes and calculate containment and usable counts before planning. The segmented subnets fit the VNet without overlap.

**Failure and repair:** Propose overlapping prefixes, explain the rejection, then restore disjoint ranges.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

**Coverage limits:** Four mocked plan runs prove the generated contained /24 allocation and reject malformed CIDR, wrong allocation size and noncanonical host bits. They do not simulate Azure overlap errors for arbitrary subnet maps.

## TFA-008 — NSGs and application security groups

**Outcome:** Prove allow and deny decisions using priorities, NSGs, and application security groups.

**Source:** [README.md](../labs/TFA-008/README.md), [main.tf](../labs/TFA-008/main.tf), [versions.tf](../labs/TFA-008/versions.tf), [probes.tf](../labs/TFA-008/probes.tf)

**Probe and expected result:** Optional Windows probes: start TCP 443 listener; remove and restore server ASG membership; test fresh client connections. With probes enabled, TCP 443 is true, then false, then true; default mode has no VM packet proof.

**Failure and repair:** web_membership_enabled=false removes the target label while the deny rule remains.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-009 — Explicit outbound connectivity

**Outcome:** Provide a deliberate outbound path with NAT Gateway and private workload subnets.

**Source:** [README.md](../labs/TFA-009/README.md), [main.tf](../labs/TFA-009/main.tf), [versions.tf](../labs/TFA-009/versions.tf)

**Probe and expected result:** Inspect subnet/NAT/public-IP associations; use the later private Windows workload to observe actual egress. Configuration attaches one explicit egress path; no inbound public VM endpoint is implied.

**Failure and repair:** Remove the NAT subnet association in a reviewed plan and identify the missing egress dependency.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-010 — Private Windows VM and IIS

**Outcome:** Bootstrap a private Windows/IIS server and verify it through the Azure control plane.

**Source:** [README.md](../labs/TFA-010/README.md), [main.tf](../labs/TFA-010/main.tf), [versions.tf](../labs/TFA-010/versions.tf), [Bootstrap-Iis.ps1](../labs/TFA-010/Bootstrap-Iis.ps1)

**Probe and expected result:** Run the authored VM command and inspect the IIS HTTP response and identifying page body. A private NIC, successful extension and expected local HTTP page are separate checks.

**Failure and repair:** Stop IIS or alter the page, distinguish service status from VM existence, then restore.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, fixture_contract, mocked_contract; Azure runtime **not run**.

**Coverage limits:** The actual authored Bootstrap-Iis.ps1 executes locally with stubbed feature/service/HTTP commands and a temporary webroot: unsuccessful install, restart required, repeated success, bad HTTP status and wrong body are tested. No Windows feature/service or Azure guest was touched. A mocked provider plan also decodes the extension command and proves it runs that exact rehearsed script with a private NIC.

## TFA-011 — Private administration with Bastion

**Outcome:** Administer Windows over Bastion without a public VM address or public RDP rule.

**Source:** [README.md](../labs/TFA-011/README.md), [main.tf](../labs/TFA-011/main.tf), [versions.tf](../labs/TFA-011/versions.tf)

**Probe and expected result:** Use the authored Bastion browser connection to the private Windows VM and inspect its NIC. Administration succeeds through Bastion while the VM has no public IP.

**Failure and repair:** Inspect an intentionally missing guest or NSG allowance; restore only the required path.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-012 — VNet peering and its limits

**Outcome:** Demonstrate direct peering connectivity and the limit of non-transitive peering.

**Source:** [README.md](../labs/TFA-012/README.md), [main.tf](../labs/TFA-012/main.tf), [versions.tf](../labs/TFA-012/versions.tf), [probes.tf](../labs/TFA-012/probes.tf)

**Probe and expected result:** Optional three-host exercise: spoke→hub, hub→isolated and spoke→isolated, with guest ICMP explicitly allowed. The two direct pairs succeed; the leaf-to-leaf path fails without transit.

**Failure and repair:** Predict the missing route before adding a forwarding design in TFA-026.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-013 — Routes, next hops, and Network Watcher

**Outcome:** Predict longest-prefix route selection and inspect the effective next hop.

**Source:** [README.md](../labs/TFA-013/README.md), [main.tf](../labs/TFA-013/main.tf), [versions.tf](../labs/TFA-013/versions.tf), [Test-RouteEvidence.ps1](../labs/TFA-013/Test-RouteEvidence.ps1)

**Probe and expected result:** Read the effective route/next-hop evidence in the exercise and compare the selected destination prefix. The deliberate discard is identified as routing, not DNS or guest failure.

**Failure and repair:** Restore the wrong next hop and compare the exact same source/destination.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, fixture_contract; Azure runtime **not run**.

**Coverage limits:** Synthetic effective-route and Network Watcher responses exercise longest-prefix selection, inactive-route exclusion, local versus discard decisions and mismatched response rejection. These are parser contracts, not observed Azure routes or packet paths.

## TFA-014 — State, addressing, and locking

**Outcome:** Explain state addresses, ownership, locking, and the limits of local state.

**Source:** [README.md](../labs/TFA-014/README.md), [main.tf](../labs/TFA-014/main.tf), [versions.tf](../labs/TFA-014/versions.tf)

**Probe and expected result:** terraform state show 'terraform_data.service["web"]'; tests/Test-LessonLocal.ps1 replays this exact line. The keyed local object is shown; repeat plan has no changes and destroy leaves empty state.

**Failure and repair:** Compare an incorrect unquoted address with the correct literal without deleting state.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, local_rehearsal; Azure runtime **not run**.

## TFA-015 — Drift, import, and refactoring

**Outcome:** Detect drift, import ownership, and preserve resource addresses while refactoring.

**Source:** [README.md](../labs/TFA-015/README.md), [main.tf](../labs/TFA-015/main.tf), [versions.tf](../labs/TFA-015/versions.tf)

**Probe and expected result:** Inspect the refresh/import/moved plans and ensure the refactor does not destroy the existing object. The intended existing object is bound once and moves address without replacement.

**Failure and repair:** Remove or mismatch the moved declaration, compare the destructive plan, then restore.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-016 — Azure remote-state bootstrap

**Outcome:** Bootstrap a protected Azure backend, migrate state, and rehearse reverse cleanup.

**Source:** [README.md](../labs/TFA-016/README.md), [main.tf](../labs/TFA-016/main.tf), [versions.tf](../labs/TFA-016/versions.tf)

**Probe and expected result:** Inspect ARM-only provider behavior and scoped role; follow bounded Blob readiness, migration and migration-back instructions. Entra-only storage has recovery protection; migration does not proceed on authorization timeout.

**Failure and repair:** Withhold Blob permission or use a failed-read fixture; retain local state and stop migration.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Migrate backend state back to local before destroying its storage.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-017 — Your first reusable module

**Outcome:** Refactor a concrete network into a reusable module with useful outputs.

**Source:** [README.md](../labs/TFA-017/README.md), [main.tf](../labs/TFA-017/main.tf), [versions.tf](../labs/TFA-017/versions.tf)

**Probe and expected result:** Read the root/module interface and compare resource addresses before and after refactoring. Callers receive useful outputs without copying internal resource logic.

**Failure and repair:** Rename an internal resource without a move and explain the proposed replacement.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-018 — Module contracts and safe changes

**Outcome:** Define module contracts and predict replacement, lifecycle, and validation behavior.

**Source:** [README.md](../labs/TFA-018/README.md), [main.tf](../labs/TFA-018/main.tf), [versions.tf](../labs/TFA-018/versions.tf)

**Probe and expected result:** Run the module contract tests and inspect a deliberate invalid-input or replacement plan. Invalid inputs fail early; replacement-producing changes are visible before apply.

**Failure and repair:** Supply an invalid module input and repair the contract or caller deliberately.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

**Coverage limits:** Three mocked plan runs cover stable output keys and empty/malformed subnet rejection. Key renaming, replacement and default lifecycle behavior remain authored plan exercises, not runtime or lifecycle simulation.

## TFA-019 — Environment and state separation

**Outcome:** Separate environment configuration, state keys, and operational ownership.

**Source:** [README.md](../labs/TFA-019/README.md), [main.tf](../labs/TFA-019/main.tf), [versions.tf](../labs/TFA-019/versions.tf)

**Probe and expected result:** Compare development/test roots or workspace outputs and record their state/backend identities. Environment data is isolated in distinct intended state locations.

**Failure and repair:** Deliberately inspect the wrong workspace before planning and switch back before any apply.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-020 — Compose a network from structured inputs

**Outcome:** Compose multiple networks from typed maps without hiding their relationships.

**Source:** [README.md](../labs/TFA-020/README.md), [main.tf](../labs/TFA-020/main.tf), [versions.tf](../labs/TFA-020/versions.tf)

**Probe and expected result:** Run the structured-input example and inspect a plan that adds exactly one named spoke. Existing keyed spokes remain unchanged while only the new key is added.

**Failure and repair:** Change a key versus its value and explain the different address consequences.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked; Azure runtime **not run**.

## TFA-021 — Test Terraform behavior

**Outcome:** Test input validation and planned behavior with mocked providers and assertions.

**Source:** [README.md](../labs/TFA-021/README.md), [main.tf](../labs/TFA-021/main.tf), [versions.tf](../labs/TFA-021/versions.tf)

**Probe and expected result:** terraform test; inspect positive and negative contract assertions and expected_failures. Mocked plans reject invalid values and preserve tested relationships without Azure access.

**Failure and repair:** Break one relationship, observe the focused failing assertion, restore it.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-022 — Azure DNS and private DNS

**Outcome:** Resolve a private name and understand zone links and authoritative DNS boundaries.

**Source:** [README.md](../labs/TFA-022/README.md), [main.tf](../labs/TFA-022/main.tf), [versions.tf](../labs/TFA-022/versions.tf)

**Probe and expected result:** Resolve the exact private lab name from the linked network and compare with its record. The expected private address is returned from the linked resolver context.

**Failure and repair:** Remove one VNet link, account for TTL/cache, then restore it.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-023 — Storage private endpoints

**Outcome:** Resolve Blob Storage to a private endpoint and disable its public service path.

**Source:** [README.md](../labs/TFA-023/README.md), [main.tf](../labs/TFA-023/main.tf), [versions.tf](../labs/TFA-023/versions.tf)

**Probe and expected result:** Resolve the Blob hostname to the output endpoint IP and compare public access configuration. The original name reaches the exact private endpoint; public service access is disabled.

**Failure and repair:** Break the zone link, compare wrong resolution with endpoint existence, then restore.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-024 — Managed identity and Key Vault

**Outcome:** Use managed identity and scoped RBAC to access private sample data.

**Source:** [README.md](../labs/TFA-024/README.md), [main.tf](../labs/TFA-024/main.tf), [versions.tf](../labs/TFA-024/versions.tf)

**Probe and expected result:** Use the authored VM identity request and read only the designated sample secret. The intended identity can read the scoped sample; normal outputs expose no secret values.

**Failure and repair:** Remove the data role or request a forbidden operation and diagnose authorization separately.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-025 — Azure Firewall and Firewall Policy

**Outcome:** Build a Firewall Policy and distinguish network rules from application rules.

**Source:** [README.md](../labs/TFA-025/README.md), [main.tf](../labs/TFA-025/main.tf), [versions.tf](../labs/TFA-025/versions.tf)

**Probe and expected result:** Compare one allowed and one denied authored flow, then query the matching Firewall evidence. Allowed and prohibited destinations differ according to policy, not accidental direct routing.

**Failure and repair:** Remove the intended allow rule, observe a policy denial, restore it.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-026 — Inspected hub-and-spoke routing

**Outcome:** Inspect selected spoke and outbound traffic without creating asymmetric routing.

**Source:** [README.md](../labs/TFA-026/README.md), [main.tf](../labs/TFA-026/main.tf), [versions.tf](../labs/TFA-026/versions.tf)

**Probe and expected result:** Inspect workload UDRs and compare allowed/denied interspoke probes with Firewall logs. Forward and return paths traverse the intended inspection point.

**Failure and repair:** Remove a destination route and distinguish bypass or asymmetry from a policy denial.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-027 — Application Gateway WAF and private IIS

**Outcome:** Serve HTTPS through WAF to healthy private IIS backends and prove a blocked request.

**Source:** [README.md](../labs/TFA-027/README.md), [main.tf](../labs/TFA-027/main.tf), [versions.tf](../labs/TFA-027/versions.tf)

**Probe and expected result:** Check public HTTPS, both backend health entries and the exact training WAF header yielding 403. Expected IIS content is reachable while the deliberate WAF signature is blocked.

**Failure and repair:** Change a probe path or service state, inspect backend health, then restore.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-028 — Monitoring and diagnostic evidence

**Outcome:** Collect diagnostics and guest telemetry, query evidence, and validate an alert.

**Source:** [README.md](../labs/TFA-028/README.md), [main.tf](../labs/TFA-028/main.tf), [versions.tf](../labs/TFA-028/versions.tf), [alerts.tf](../labs/TFA-028/alerts.tf)

**Probe and expected result:** Emit one named Application event; query it; inspect the scheduled rule Fired then Resolved instance. Heartbeat, exact event row and alert lifecycle are separate evidence items.

**Failure and repair:** Change only the query marker, compare ingested records with no match, restore it.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract, fixture_contract; Azure runtime **not run**.

## TFA-029 — VPN and hybrid routing foundations

**Outcome:** Explain IPsec, gateway transit, propagation, route selection, and BGP purpose.

**Source:** [README.md](../labs/TFA-029/README.md), [main.tf](../labs/TFA-029/main.tf), [versions.tf](../labs/TFA-029/versions.tf)

**Probe and expected result:** Read the local VPN/routing model and explain gateway ownership, propagation and learned prefixes. The model distinguishes a tunnel, a route and peering transit settings.

**Failure and repair:** Predict the missing return prefix or overlapping range before building gateways.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-030 — Simulated on-premises connectivity

**Outcome:** Prove an encrypted connection to an Azure-hosted simulated on-premises network.

**Source:** [README.md](../labs/TFA-030/README.md), [main.tf](../labs/TFA-030/main.tf), [versions.tf](../labs/TFA-030/versions.tf)

**Probe and expected result:** Inspect both VPN connection states and execute the authored cross-network private probe. Both connections report Connected and the intended private traffic succeeds.

**Failure and repair:** Use a mismatched shared key, diagnose the tunnel failure, restore matching keys.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-031 — Hybrid DNS with Private Resolver

**Outcome:** Resolve Azure private services and corporate lab names across the VPN.

**Source:** [README.md](../labs/TFA-031/README.md), [main.tf](../labs/TFA-031/main.tf), [versions.tf](../labs/TFA-031/versions.tf), [reverse-dns.tf](../labs/TFA-031/reverse-dns.tf)

**Probe and expected result:** From corporate DNS resolve the original Blob name; from Azure probe resolve files.corp.tfa.internal. Blob resolves to its exact private endpoint and the corporate record resolves to 10.131.2.4.

**Failure and repair:** Disable only the corporate rule, clear/expire caches, verify one-direction failure and restore.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract, fixture_contract; Azure runtime **not run**.

## TFA-032 — RBAC, policy, budgets, and locks

**Outcome:** Apply practical permissions, policy, budget notifications, and resource locks.

**Source:** [README.md](../labs/TFA-032/README.md), [main.tf](../labs/TFA-032/main.tf), [versions.tf](../labs/TFA-032/versions.tf), [Test-GovernanceEvidence.ps1](../labs/TFA-032/Test-GovernanceEvidence.ps1)

**Probe and expected result:** Inspect the scoped assignment, policy, budget and lock; follow the explicit unlock-before-destroy sequence. Each control addresses a distinct question and cleanup removes the lock deliberately.

**Failure and repair:** Attempt the documented policy violation or deletion with a lock, then repair the exact control.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract, fixture_contract; Azure runtime **not run**.

**Coverage limits:** Existing provider mocks cover default lock opt-in and Reader name. Synthetic governance response cases additionally verify exact scoped policy denial, calculated budget threshold plus separately observed notification, resource persistence, successful unlock and six invalid evidence cases. Actual policy enforcement, email delivery, billing and lock behavior remain unverified.

## TFA-033 — Provider aliases and subscription boundaries

**Outcome:** Map provider aliases explicitly and understand cross-subscription prerequisites.

**Source:** [README.md](../labs/TFA-033/README.md), [main.tf](../labs/TFA-033/main.tf), [versions.tf](../labs/TFA-033/versions.tf)

**Probe and expected result:** Run the alias mapping tests and inspect which provider configuration each module receives. Both explicit mappings work in the training subscription without hidden defaults.

**Failure and repair:** Omit the required provider mapping and restore the declared interface.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-034 — Network incident investigation

**Outcome:** Diagnose a broken service by following DNS, routes, enforcement, and application health.

**Source:** [README.md](../labs/TFA-034/README.md), [main.tf](../labs/TFA-034/main.tf), [versions.tf](../labs/TFA-034/versions.tf), [incidents.tf](../labs/TFA-034/incidents.tf)

**Probe and expected result:** Compare hostname, direct-IP TCP, effective route/NSG and W3SVC across four selectable incidents. dns-wrong, route-drop, nsg-block and app-stopped have different decisive evidence.

**Failure and repair:** Select each fault once; restore healthy between cases and re-probe HTTP.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract, fixture_contract; Azure runtime **not run**.

## TFA-035 — Git collaboration and pull-request checks

**Outcome:** Review infrastructure changes through credential-free pull-request quality checks.

**Source:** [README.md](../labs/TFA-035/README.md), [main.tf](../labs/TFA-035/main.tf), [versions.tf](../labs/TFA-035/versions.tf)

**Probe and expected result:** Run the credential-free check commands and inspect .github/workflows/ci.yml. Formatting, tests and document checks fail on their respective controlled errors.

**Failure and repair:** Introduce one formatting or broken-link defect, observe the exact check, restore.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-036 — GitHub Actions authentication with OIDC

**Outcome:** Configure a federated managed identity for GitHub Actions and backend access.

**Source:** [README.md](../labs/TFA-036/README.md), [main.tf](../labs/TFA-036/main.tf), [versions.tf](../labs/TFA-036/versions.tf), [federation.workflow.yml.example](../labs/TFA-036/federation.workflow.yml.example)

**Probe and expected result:** Inspect the inactive minimal workflow and mock subject tests; optional later dispatch reads only the lesson RG. Offline checks establish the trust contract; actual token exchange is explicitly unverified.

**Failure and repair:** Mismatch an environment in a fixture, explain federation rejection, restore the exact subject.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract, fixture_contract; Azure runtime **not run**.

## TFA-037 — Reviewed plan, apply, and destroy workflows

**Outcome:** Review a saved plan and use an explicitly invoked protected deployment workflow.

**Source:** [README.md](../labs/TFA-037/README.md), [main.tf](../labs/TFA-037/main.tf), [versions.tf](../labs/TFA-037/versions.tf), [Demo-SavedPlan.ps1](../labs/TFA-037/Demo-SavedPlan.ps1)

**Probe and expected result:** Run Demo-SavedPlan.ps1 plan/apply/plan-destroy/destroy on the local contract and reject altered plans. The exact reviewed artifact applies; tampered and wrong-operation artifacts fail before Terraform apply.

**Failure and repair:** Alter a disposable plan byte or manifest operation and observe a rejected apply.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract, local_rehearsal; Azure runtime **not run**.

## TFA-038 — Recovery and controlled upgrades

**Outcome:** Recover ownership and state, resume interrupted work, and review provider upgrades.

**Source:** [README.md](../labs/TFA-038/README.md), [main.tf](../labs/TFA-038/main.tf), [versions.tf](../labs/TFA-038/versions.tf)

**Probe and expected result:** Rehearse the local recovery example and compare version/lockfile changes with a fresh plan. Recovery preserves the intended object bindings and exposes changes before upgrade apply.

**Failure and repair:** Use an interrupted or stale local state fixture, inspect it, then restore the known binding.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-039 — Capstone architecture workshop

**Outcome:** Complete the address plan, traffic matrix, permissions, cost review, and readiness gate.

**Source:** [README.md](../labs/TFA-039/README.md), [main.tf](../labs/TFA-039/main.tf), [versions.tf](../labs/TFA-039/versions.tf)

**Probe and expected result:** Complete address, traffic, DNS, cost and permission worksheets; run local and fixture readiness modes. All design decisions have named evidence or explicit unverified status before a live learner deployment.

**Failure and repair:** Find an overlapping CIDR or unsupported readiness fixture and repair the design.

**Cleanup:** Destroy only this local lesson state and verify an empty resource list; no Azure cleanup is implied. Independent root; prerequisites teach concepts and do not retain infrastructure.

**Evidence level:** authored_source, static_checked, mocked_contract; Azure runtime **not run**.

## TFA-040 — Build Terraforming Azure

**Outcome:** Integrate and prove the complete staged regional hub-and-spoke architecture.

**Source:** [README.md](../labs/TFA-040/README.md), [main.tf](../labs/TFA-040/main.tf), [versions.tf](../labs/TFA-040/versions.tf)

**Probe and expected result:** Read Test-Capstone and stage mock tests; follow the authored exact-IP and full traffic-matrix runtime probes later. All four stages have explicit offline evidence; Azure runtime is recorded as not run in this overhaul.

**Failure and repair:** Use the documented DNS, route and policy fixtures; restore the healthy stage contract.

**Cleanup:** Use this root's documented whole-root destroy; capture its actual group name first, stop on errors, and verify no managed objects remain. TFA-040 depends on the separate bootstrap backend; destroy capstone before migrating bootstrap state locally and destroying that backend.

**Evidence level:** authored_source, static_checked, mocked_contract, fixture_contract; Azure runtime **not run**.
