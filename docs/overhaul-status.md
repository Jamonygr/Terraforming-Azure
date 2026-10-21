# Course overhaul — implementation record

The 2026-10-21 review covers course content, Terraform, PowerShell, the learning
website and delivery. The release boundary is **code/site validation with Azure
runtime unverified**. Live Azure deployment, traffic, failure, recovery and teardown
passes are excluded from this overhaul and its release gates.

The [validation record](validation.md) identifies checks actually executed. The
[40-lab outcome map](curriculum-evidence.md) separates authored outcomes from
configuration, local, fixture and learner runtime evidence. Cost estimates are
[dated, reproducible assumptions](cost-estimates.md), not measurements of a bill.

| Finding | Implemented change | Evidence or remaining boundary |
|---|---|---|
| F01 — tracked variable/secret files | Ignore all real JSON variable files; narrow, content-checked stage exceptions; scan tracked and untracked source | Forced-add, JSON variable, example and redaction regressions |
| F02 — PowerShell resource address quoting | Correct Windows/native argument quoting in TFA-014 | Local `terraform_data` move, plan, restore and destroy rehearsal |
| F03 — backend lesson control/data dependency | TFA-016 creates Storage through ARM before Entra backend migration; documents role propagation and cleanup | Schema/mock checks; Azure RBAC propagation unverified |
| F04 — progress updates across tabs | Store individual fields and use reset generations; merge storage events | Two-page browser regression and store tests |
| F05 — corrupt nested progress | Normalize known labs/questions; preserve stable option identity and question revision | Malformed object/array/selection tests; edited quizzes require a fresh attempt |
| F06 — tests of constant design labels | Assert configured NICs, routes, NSGs, private endpoint policies, stage relationships and rules | Five isolated architecture mutations must fail |
| F07 — beginner entry point | Concepts before installation; installation before clone/CLI work | README entry links and TFA-001/002 review |
| F08 — incomplete operational outcomes | Add TFA-028 alert lifecycle, TFA-031 reverse DNS, TFA-034 selectable incident configurations | Mocked resources and positive/negative synthetic evidence |
| F09 — operator CIDR bypasses | Require canonical IPv4 network notation, meaningful prefix and valid octets | Reject open/default aliases, host bits, malformed/IPv6 and zero-padded forms |
| F10 — weak DNS/data readiness | Expose exact private endpoint IPs; bounded DNS/RBAC retry with fatal authorization distinction | Exact-IP and retry response fixtures; real readiness unverified |
| F11 — unstructured capstone verification | Stage-aware PASS/FAIL/SKIP evaluator; explicit evidence provenance | Missing observations skip; contradictory observations fail; synthetic results never certify Azure |
| F12 — implicit authenticated readiness | Local mode by default; explicit synthetic mode and separate Azure read-only opt-in adapter | Command adapter fixtures, timeout and no-fallback checks |
| F13 — early network outcome claims | TFA-008/012 default to configuration inspection with optional priced VM probes after TFA-010 | Mock contracts; packet outcomes remain learner exercises |
| F14 — delivery exercises need concrete examples | Inert minimal OIDC workflow example and local saved-plan exercise | Federation contract fixtures and changed-configuration saved-plan rehearsal |
| F15 — incomplete costs | All 40 default footprints, optional probes and four cumulative stages; disks/IPs/capacity/DNS/alerts included | Exact dated meter selection, unit math and table drift tests |
| F16 — cleanup identity | Capture deployed identifiers before destroy and verify that inventory | Lesson script review; Azure deletion not executed |
| F17 — quiz quality | Review 200 prompts; replace 600 weak distractors; remove predictable correct positions | Unique IDs/answers plus browser scoring by stable option ID |
| F18 — generic teaching material | Topic-specific explanations, predictions, repairs and diagrams; explicit outcome contracts | Source review and the 40-lab evidence map |
| F19 — duplicated lesson metadata | Generate duration, costs, prerequisite links, phase and diagram metadata from one catalog | Source synchronization and site generation tests |
| F20 — contrast/mobile behavior | Accessible theme colors, readable diagrams and responsive layouts | Chromium desktop/mobile, keyboard and axe checks |
| F21 — fragile import/storage behavior | Import preview with merge/replace; session-only warning/export; isolated fetch failure and retry | Browser denied-storage, damaged import, multi-tab and failed-fetch cases |
| F22 — artwork/build metadata | Optimized WebP cover, social metadata and deterministic LF site generation | Original preserved; repeat config hash and generated-link checks |
| F23 — partial/doubled CI | Shared test entry point, Linux full lane, Windows behavior lane, dependency locks and pinned actions | Policy/actionlint checks; Pages consumes the successful main-run artifact |
| F24 — delivery controls | Required main checks documented; cloud readiness gate runs before Azure login | Repository protection status recorded in validation; Azure setup remains explicitly unconfigured |
| F25 — misleading DNS Firewall rule | Remove unused resolver-to-corporate rule; explain direct VPN DNS path | Route/rule assertions and the traffic matrix |

## How to interpret the result

A mock checks configuration relationships. A synthetic response checks whether a
verifier interprets evidence correctly. Local execution validates Windows quoting,
state handling or saved plans using Terraform's built-in resources. Browser checks
exercise the generated website. None establishes cloud provisioning, regional
availability, access propagation, extension installation, service health, DNS/VPN
reachability or Azure enforcement. Those remain unverified.

Run the shared [contributor checks](../CONTRIBUTING.md) after changes. Keep this
record aligned with the resulting code, and update the validation page only after
the named checks actually finish. The manual learner deployment path is documented
in [delivery](delivery.md); it is separate from the course publishing gate.
