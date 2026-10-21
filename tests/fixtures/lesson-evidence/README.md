# Authored lesson fixtures

These are synthetic offline responses, not captured Azure evidence. The alert file models two ordered Azure alert essentials observations. DNS records model the relevant Resolve-DnsName fields; expected addresses are supplied separately to the assertion. Incident observations normalize the lesson's DNS, route, NSG, direct-IP TCP and service probes. The federation fixtures model authoring metadata; they are not JWTs and cannot authenticate.

Run `pwsh -NoProfile -File tests/Test-LessonEvidence.ps1` from the repository root. It rejects a different private endpoint address and a mismatched environment, classifies five incident cases, verifies the alert ordering, and executes the built-in local saved-plan rehearsal. It never calls Azure.

The route responses cover active local and discard prefixes plus an inactive /32. Governance evidence combines normalized policy errors, budget spend/notification and before/after lock observations; no message is sent. The actual TFA-010 bootstrap is exercised separately with stubbed feature/service/HTTP calls and temporary files.
