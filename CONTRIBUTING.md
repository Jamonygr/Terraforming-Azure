# Contributing

Teach the behavior, then demonstrate it. Each numbered lesson has runnable code,
a prediction, concrete verification, a controlled failure, cleanup, and five
original quiz questions with explanations. Keep Windows/PowerShell 7 instructions
primary. Update `curriculum/labs.json` when changing navigation or dependencies.

## Prepare contributor tools

Complete TFA-002 for the learner tools. Contributors also need Python 3.12,
Node 24, [TFLint 0.63.1](https://github.com/terraform-linters/tflint/releases/tag/v0.63.1)
and [actionlint 1.7.12](https://github.com/rhysd/actionlint/releases/tag/v1.7.12).
Check release checksums when installing binaries. From the repository root:

```powershell
py -3.12 -m venv .venv
./.venv/Scripts/Activate.ps1
python -m pip install -r requirements-site.txt
npm ci
npx playwright install chromium
./scripts/Test-Course.ps1
```

On Linux use the same dependency locks, activate the Unix venv path, and install
Chromium with `npx playwright install --with-deps chromium`. PowerShell must be
available as `pwsh`. CI uses explicit Ubuntu 24.04 and Windows 2025 runners.

## Run appropriate checks

`Test-Course.ps1` is the shared local/CI entry point. It checks metadata, source
guards, every Terraform root, mocks, targeted architecture mutations, local
PowerShell behavior, diagrams, the strict website build and browser behavior.
It rejects unmocked external providers before running Terraform tests.

- `-WindowsOnly` runs source and behavior regressions, including copied local
  state commands and synthetic DNS/RBAC/route responses.
- `-DocsOnly` validates metadata and builds/checks the site.
- `-SkipTests` skips behavior, mutation and browser tests; this partial evidence
  is insufficient for a release.
- `-Python <path>` selects your virtual environment. Use `-Jobs 2` only after
  initializing the provider cache once; serial initialization is the default.

After catalog changes, run `python tools/sync_catalog.py` and
`python tools/sync_lesson_metadata.py`. After cost quantity changes, run
`python tools/cost_estimate.py --write`. Generate the site with
`python tools/build_site.py`; `mkdocs.yml` is generated, not manually edited.
A second generation must leave the tracked config byte-for-byte unchanged.

## Evidence and publication

**Code/site validated; Azure runtime unverified** is the release boundary. Live
Azure deployment, token exchange, traffic, failure injection, recovery and teardown
passes are excluded from this overhaul and its release gates. The manual learner
workflow remains a separate opt-in path with explicit setup.

Keep lesson IDs and Terraform addresses stable; add moved blocks and migration
notes for address changes. Make a deliberately wrong configuration fail a relevant
assertion. Testing a constant design label is not architecture evidence.

Keep credentials, state, saved plans, PFX files, and real tenant values out of Git.
Explain scanner suppressions next to the relevant training example. Keep each
diagram readable at browser width and provide text equivalents for important paths.
