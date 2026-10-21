# Cost and cleanup

Costs are part of each exercise. Start with the **[complete dated estimates](cost-estimates.md)**: all 40 lesson inventories, optional probe topologies and the four cumulative capstone stages. The tables count every declared fixed-price component and state the assumed Storage/log usage. They are estimates, not bills observed from a deployed environment.

## Before each paid stage

1. Read the lesson resource inventory and the dated assumptions.
2. Reproduce its estimate locally, without login or a network request:

   ```powershell
   ./scripts/Get-LabCostEstimate.ps1 -Lab TFA-031 -Hours 4
   ./scripts/Get-LabCostEstimate.ps1 -Lab TFA-012 -OptionalProbes -Hours 4
   ./scripts/Get-LabCostEstimate.ps1 -Stage hybrid -Hours 24
   ```

3. Review the current [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/) and add traffic, processing, operations and any extra log ingestion. Rates and regional availability can change.
4. Review the saved plan, permissions, resource quotas and cleanup commands before choosing to deploy.
5. Record the start time. Destroy after the exercise and check billing later because Cost Management data is delayed.

Firewall, Bastion, WAF, DNS Resolver and VPN gateways have substantial charges while provisioned, even when no learner is actively using them. Review the cost checkpoint before **secure**, **applications** and **hybrid**. The full default hybrid estimate on 21 October 2026 is **USD 14.31 for four hours** or **USD 85.61 for 24 hours**, including the stated log/storage assumptions and excluding additional usage. The detailed table is the source for these numbers.

## Rates, units and maintenance

[The price snapshot](cost-snapshot.json) records 20 exact meter selections, products, regions, tiers, units and effective dates. [The inventory](../curriculum/costs.json) separates default and optional quantities. The table generator has unit tests for monthly conversion, daily DNS billing and the required capstone quantities:

```powershell
python tools/cost_estimate.py --check
python tools/cost_estimate.py --stage applications --hours 4
```

Maintainers can inspect current candidates with `./scripts/Get-LabCostEstimate.ps1 -Refresh`. This calls only Microsoft's public Retail Prices API; no subscription access is used. Its optional `-SelectionFile docs/cost-selection.example.json` mode is retained for comparing the earlier selected-hourly subtotal. That subtotal is not the complete course estimate. NAT/Private Link use Global meters and DNS Resolver uses Zone 1 meters, so region-only candidate searches do not find every service.

For a full refresh, run `python tools/refresh_cost_snapshot.py --output work/cost-candidate.json`. It requires an exact product/region/tier/unit match and rejects missing or ambiguous selections. Review the candidate against `docs/cost-snapshot.json`, update the snapshot deliberately, then run `python tools/cost_estimate.py --write`. Never infer zero cost from a missing meter. Never treat a monthly meter as hourly. The quantity model assumes 128 GiB OS disks; verify the selected image and disk size. Extra WAF capacity, longer deployments, extra disks and interrupted cleanup increase the bill.

Budget alerts notify; they do not stop resources or enforce a spending cap. Local/mock validation does not prove regional availability, successful deployment or teardown. **Azure runtime is unverified; live Azure passes are excluded from the overhaul release gates.**

## Cleanup is part of the exercise

For independent local-state labs, run the documented `terraform plan -destroy
-out tfplan`, inspect it, then `terraform apply tfplan`. Confirm each resource
group no longer exists using `az group exists --name <actual-output-name>`.

For TFA-040, destroy the capstone before removing its backend. A locked resource
must be deliberately unlocked before destruction. Azure Key Vault soft deletion
and provider deletion safeguards can retain recoverable objects; use the
documented retention behavior rather than claiming every reserved name instantly
becomes reusable. Inspect for billable disks, public IPs and gateways left after
an interrupted deletion.

Never delete state to make an error disappear. Reconcile configuration and
ownership, finish destruction, then migrate bootstrap state locally and destroy
the backend. Protect state backups and certificate/password material until the
exercise is closed; remove local sensitive artifacts afterward.
