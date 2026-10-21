# Validation status

Validated locally on **2026-10-21** with Terraform **1.15.8**, AzureRM **4.77.0**,
PowerShell **7.6.7**, Python **3.12**, TFLint **0.63.1**, and actionlint **1.7.12**.

| Check | Status and evidence |
|---|---|
| Course catalog, questions, prerequisites, local links and SVGs | PASS: 40 lessons, 200 unique question IDs, six phases |
| Terraform initialization and schema validation | PASS: all 45 independent lesson, environment, bootstrap and tested module roots |
| Mock/local Terraform suites | PASS: foundation, advanced patterns, backend safeguards, and all four capstone stages |
| Terraform formatting and TFLint | PASS: no formatting differences or lint findings |
| GitHub workflow syntax | PASS: actionlint |
| Focused source security checks | PASS: credential/generated-file/private-VM policies |
| Saved-plan identity/integrity/age tests | PASS: four unit tests, including commit/stage/operation/certificate mismatches |
| Browser-local progress recovery | PASS: invalid JSON, invalid root types and malformed lesson entries |
| PowerShell source parsing | PASS: all course .ps1 sources |
| Training certificate helper | PASS: Windows PFX generation, protected readback and scratch cleanup |
| Strict website build and internal link checks | PASS: 40 rendered lessons and 200 questions |
| Browser behavior | PASS: quiz feedback, persisted lesson/quiz progress, practice selection, remembered theme, search, mobile no-overflow check |
| Live Azure deployment / second plan / traffic tests | **NOT RUN: code and local validation only, as requested** |
| Live failure injection / recovery / teardown | **NOT RUN** |

The Linux publishing workflow repeats source validation, lint, mock tests and the
strict site build. Its actual result is visible in [GitHub Actions](https://github.com/Jamonygr/Terraforming-Azure/actions).
No paid deployment runs from a push, pull request, or website visit. The manual
Azure workflow is unconfigured until a learner supplies their own identity,
subscription, backend, environment protections and runtime secrets.

Mock tests check planned architecture and input contracts. They do not prove
Azure API acceptance, current regional SKUs/quota, policy restrictions, permission
propagation, extension downloads, application health, VPN connectivity, or actual
network/DNS enforcement. Use the live smoke matrix before claiming those results.

The local state-recovery exercise was also rehearsed in an isolated scratch
folder: losing ownership produced a changed plan (exit 2), restoring the exact
backup produced no changes (exit 0), then local resources were destroyed. This was
not an Azure recovery test. Saved plans, state, certificate material and generated
provider caches are excluded from Git.
