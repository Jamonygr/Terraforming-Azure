# Contributing

Teach the behavior, then demonstrate it. Each numbered lesson has runnable code,
a prediction, concrete verification, a controlled failure, cleanup, and five
original quiz questions with explanations. Keep Windows/PowerShell 7 instructions
primary. Update `curriculum/labs.json` when changing navigation or dependencies.

Use Python 3.12+ for the website. Run `./scripts/Test-Course.ps1`,
`tflint --recursive`, and `actionlint`, then `python tools/build_site.py` and
`python -m mkdocs build --strict` before opening a pull request. Cloud tests are
explicitly invoked by an operator in a disposable training subscription; record
which stage, region, version, and behaviors were actually verified. A static
validation pass must never be described as a live Azure deployment pass.

Keep credentials, state, saved plans, PFX files, and real tenant values out of Git.
Explain scanner suppressions next to the relevant training example. Keep each
diagram readable at browser width and provide text equivalents for important paths.
