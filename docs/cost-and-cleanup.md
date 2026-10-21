# Cost and cleanup

Costs are part of each exercise. Local/mocked lessons create no cloud resources.
Low-cost labels describe relative footprint, not a spending limit. Region, SKU,
currency, discounts, minimum capacity, traffic, disk, logs and taxes affect actual
charges. Budgets notify; they do not enforce a hard spending cap.

## Before each paid stage

1. Read the lesson inventory and resource SKU defaults.
2. Obtain current West Europe retail rates using
   `./scripts/Get-LabCostEstimate.ps1`; review ambiguous meters rather than choosing
   the cheapest one. The script returns candidates, not a billing quote.
3. Complete the price worksheet below for both a four-hour and 24-hour session.
4. Review the plan, quota, teardown commands and regional availability.
5. Record the start time and destroy after the exercise. Check Cost Management
   later because billing data has a delay.

Use [Azure's pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/)
and the [official Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices)
to verify current meter selection. Do not carry an old numeric estimate forward
as if it were a current quote.

## Session worksheet

### Dated example: selected hourly services

Retrieved from the official Retail Prices API on **2026-10-21**, West Europe,
USD retail consumption pricing. These are selected fixed/hourly services only,
not the full deployment bill. The sample assumes one WAF instance's illustrative
10 capacity units; verify actual billed capacity and add every remaining row.

| Selected meter | Quantity | USD/hour total | Four hours | 24 hours |
|---|---:|---:|---:|---:|
| Firewall Standard deployment | 1 | 1.2500 | 5.00 | 30.00 |
| Bastion Standard gateway | 1 | 0.2900 | 1.16 | 6.96 |
| WAF_v2 fixed cost | 1 | 0.4680 | 1.87 | 11.23 |
| WAF_v2 capacity units | 10 | 0.1440 | 0.58 | 3.46 |
| VpnGw1AZ | 2 | 0.4200 | 1.68 | 10.08 |
| **Selected-meter subtotal** | | **2.5720** | **10.29** | **61.73** |

Reproduce using `./scripts/Get-LabCostEstimate.ps1 -SelectionFile
docs/cost-selection.example.json`. The JSON records exact meter IDs and quantities.
This subtotal excludes Windows VMs, disks, DNS Resolver endpoints/rulesets,
private endpoints, NAT, public IPs, Storage, traffic, logs and taxes. DNS Resolver
meters are monthly, prorated to hours, and can use global/zone geography in the
API rather than the `westeurope` ARM region; check the [DNS pricing page](https://azure.microsoft.com/en-us/pricing/details/dns/)
instead of assuming a missing region result means zero cost.

### Complete the remaining footprint

| Resource | Full-stage quantity | Four-hour estimate | 24-hour estimate |
|---|---:|---|---|
| Firewall Standard | 1 deployment | hourly meter × 4 + processed data | hourly meter × 24 + processed data |
| Bastion Standard | 1 deployment | hourly meter × 4 + transfer | hourly meter × 24 + transfer |
| Application Gateway WAF_v2 | 1 deployment | gateway hourly + capacity units × 4 | gateway hourly + capacity units × 24 |
| VPN Gateway | 2 selected gateway SKUs | sum of gateway hourly meters × 4 | sum of gateway hourly meters × 24 |
| DNS Private Resolver | inbound + outbound endpoint | endpoint/ruleset meters × 4 + queries | endpoint/ruleset meters × 24 + queries |
| Windows VMs | inspect plan; IIS pair + operations + corporate | quantity × Windows SKU hourly × 4 + disks | quantity × Windows SKU hourly × 24 + disks |
| Private endpoints | Blob + Key Vault | endpoint hours + processed data | endpoint hours + processed data |
| Corporate NAT Gateway | 1 | hourly × 4 + processed data | hourly × 24 + processed data |
| Supporting services | public IPs, disks, Storage, peering, logs | selected meters and usage | selected meters and usage |

The cost script supports an explicit selection JSON file with per-meter quantity.
Once a regional meter has been verified, it prints dated four-hour/24-hour totals
for those selected hourly meters. Add variable consumption and monthly units
separately; it deliberately refuses to treat non-hourly prices as hourly prices.

## Teardown is a tested operation

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
