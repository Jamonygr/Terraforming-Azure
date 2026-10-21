# Validation status

**Code/site validated; Azure runtime unverified.** The full local runner passed on
**2026-10-21** with Terraform **1.15.8**, AzureRM **4.77.0**, PowerShell **7.6.7**,
Python **3.12.14**, Node **24.12.0**, TFLint **0.63.1** and actionlint **1.7.12**.
MkDocs **1.6.1**, Material **9.6.20** and Playwright **1.64.1** are dependency-locked.

| Check | Status and evidence |
|---|---|
| Course catalog, questions, prerequisites, local links and SVGs | PASS: 40 lessons, 200 unique question IDs, six phases |
| Terraform initialization and schema validation | PASS: all 45 independent lesson, environment, bootstrap and tested module roots |
| Mock/local Terraform suites | PASS: 29 roots with external providers mocked; capstone module 5 runs and root 13 runs, including cumulative stages and invalid CIDRs |
| Architecture mutation checks | PASS: five deliberate changes rejected — public NIC, forced-tunnel WAF subnet, disabled PE policies, broad Firewall source and missing return route |
| Terraform formatting and TFLint | PASS: no formatting differences or lint findings |
| GitHub workflow syntax | PASS: actionlint |
| Focused source security checks | PASS: credential/generated-file/private-VM policies |
| Python regression suite | PASS: 33 tests covering secret-file policy, offline providers, saved plans, costs, curriculum, site generation and workflow policy |
| Progress store | PASS: 10 Node regressions; normalized imports, stable answers, per-field merging and reset generations |
| PowerShell source parsing | PASS: course .ps1 and .psm1 sources |
| Capstone/readiness response handling | PASS: 39 synthetic/local cases; missing observations SKIP and wrong observations FAIL |
| Local lesson behavior | PASS: native keyed-address quoting, state lookup, repeat plan, cleanup and exact saved-plan apply/tamper/operation checks |
| Synthetic lesson evidence | PASS: actual IIS bootstrap under command stubs, route/next-hop disagreement, governance denial/notification/unlock, alert lifecycle, exact bidirectional DNS, incidents and federation mismatches; no token exchange |
| Strict website build and internal link checks | PASS: 40 rendered lessons and 200 questions |
| Browser behavior | PASS: 24 Chromium tests, including 12 axe cases; keyboard, desktop/mobile, search, themes, quizzes, two tabs, storage denial and fetch recovery |
| Live Azure authentication/deployment/traffic/failure/recovery/teardown | **EXCLUDED from this overhaul and its release gates; not run** |

Reproduce with `./scripts/Test-Course.ps1` after [contributor setup](../CONTRIBUTING.md).
Linux runs the full check; Windows runs the focused native/behavior lane. Actual
commit-specific results are visible in [GitHub Actions](https://github.com/Jamonygr/Terraforming-Azure/actions).
Pages consumes the successful main quality run's site artifact, without a second
build. Pull-request artifacts cannot enter publishing.

Repository controls were configured and read back on 2026-10-21: `main` requires
a pull request, up-to-date **Linux course checks** and **Windows behavior checks**,
and linear history. Protection includes administrators; force pushes and deletion
are disabled. Zero mandatory approving reviewers permits the sole owner to merge
a passing PR. The Pages environment permits the main branch.

The Azure lifecycle remains unconfigured: `AZURE_WORKFLOW_READY` is unset and
there are no `azure-plan`/`azure-course` environments. The guard stops before Azure
login. A learner must deliberately configure their own identity, subscription,
backend, environment protections and secrets to use that separate workflow.

Mock tests check planned architecture and input contracts. They do not prove
Azure API acceptance, current regional SKUs/quota, policy restrictions, permission
propagation, extension downloads, application health, VPN connectivity, or actual
network/DNS enforcement. The learner smoke matrix describes intended evidence;
it is not an executed pass or a release requirement for this overhaul.

Local state and saved-plan exercises use Terraform built-in resources in isolated
temporary folders and destroy their local state after verification. Saved plans,
state, certificate material and provider caches are excluded from Git. See the
[40-lab evidence map](curriculum-evidence.md) and [implementation record](overhaul-status.md)
for the distinction between authored exercises and automated coverage.
