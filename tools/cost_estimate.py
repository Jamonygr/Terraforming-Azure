"""Reproduce dated course estimates offline. Never authenticates or deploys Azure."""
import argparse
from decimal import Decimal, ROUND_CEILING
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def line_cost(meter, quantity, hours, snapshot):
    quantity, hours = Decimal(str(quantity)), Decimal(str(hours))
    if not quantity.is_finite() or quantity < 0 or not hours.is_finite() or hours <= 0:
        raise ValueError('Finite nonnegative quantities and positive hours are required.')
    rate = Decimal(str(meter['retailPrice']))
    basis = meter['basis']
    if basis == 'hour': factor = hours
    elif basis == 'month': factor = hours / Decimal(str(snapshot['monthly_hours']))
    elif basis == 'month_daily': factor = (hours / 24).to_integral_value(rounding=ROUND_CEILING) / Decimal(str(snapshot['monthly_days']))
    elif basis == 'usage_daily': factor = hours / 24
    else: raise ValueError(f'Unsupported billing basis: {basis}')
    return rate * quantity * factor


def estimate(resources, hours, snapshot):
    hours = Decimal(str(hours))
    if not hours.is_finite() or hours <= 0:
        raise ValueError('Finite positive hours are required, including for zero-cost roots.')
    return sum((line_cost(snapshot['meters'][key], qty, hours, snapshot) for key, qty in resources.items()), Decimal(0))


def render(snapshot, inventory):
    lines = ['# Dated course cost estimates', '',
             f"Retrieved **{snapshot['date']}**, West Europe, **USD** public consumption prices. These are planning estimates, not an observed bill.", '',
             'Reproduce without Azure credentials or network access: `python tools/cost_estimate.py --check`.', '',
             '## Assumptions and complete fixed footprint', '',
             '- VM: Windows Server B2s, no Hybrid Benefit or reservation; image OS disk assumed 128 GiB (S10 HDD in standalone labs, E10 SSD in the capstone). Verify the selected image size before deployment.',
             '- WAF reserves one instance, hence ten capacity units. More demand increases capacity charges.',
             f'- Monthly endpoint, disk, alert and storage rates use {snapshot["monthly_hours"]} hours. DNS zones use daily billing and a {snapshot["monthly_days"]}-day pricing month: even a four-hour session includes one zone-day; crossing midnight can add another.',
             '- Each Storage account is modelled with 1 GB Hot LRS data. Log Analytics, where configured, assumes 1 GB/day; this is a usage assumption, not a guarantee or spending limit.',
             '- No subscription-wide free grants are deducted for logs or alerts. Global NAT/Private Link and Zone 1 DNS meters are used where the API has no West Europe row.',
             '- Resource groups, VNets, subnets, NICs, NSGs, route tables, identity/RBAC, DCRs and Standard Key Vault have no fixed deployment fee. Their traffic, storage or API usage can incur charges.',
             '- Excludes traffic/egress, peering, Firewall/NAT/PE data processing, DNS queries, disk I/O, Blob/Key Vault operations, extra log ingestion/retention, tax, discounts, and resources outside the declared examples. These usage-dependent charges must be added for the planned session.',
             '- Standalone lessons exclude resources from other labs. Capstone stages include the separate backend account. Optional probes are reported separately.', '',
             '## Every lesson', '', '| Lab | Fixed/resource assumptions | 4 hours USD | 24 hours USD |', '|---|---|---:|---:|']
    for lab, entry in inventory['labs'].items():
        resources = entry['resources']
        desc = ', '.join(f'{qty:g} × {key}' for key, qty in resources.items()) or ('See cumulative stages' if lab == 'TFA-040' else 'No fixed-price deployment in default root')
        if lab == 'TFA-040':
            lines.append(f"| {lab} | {desc} | See stages | See stages |")
        else:
            lines.append(f"| {lab} | {desc} | {estimate(resources,4,snapshot):.2f} | {estimate(resources,24,snapshot):.2f} |")
        if entry.get('optional_resources'):
            optional = entry['optional_resources']
            lines.append(f"| {lab} optional probes | Additional VM/disks/NAT/public IPs | +{estimate(optional,4,snapshot):.2f} | +{estimate(optional,24,snapshot):.2f} |")
    lines += ['', '## Cumulative capstone stages', '', '| Stage | 4 hours USD | 24 hours USD |', '|---|---:|---:|']
    for stage, entry in inventory['stages'].items():
        lines.append(f"| {stage} | {estimate(entry['resources'],4,snapshot):.2f} | {estimate(entry['resources'],24,snapshot):.2f} |")
    lines += ['', 'These are cumulative totals: do not add them unless you actually keep each stage deployed for a separate session.', '',
              '| Meter key | Hybrid quantity | USD per original unit | Original unit / model |', '|---|---:|---:|---|']
    for key, meter in snapshot['meters'].items():
        lines.append(f"| {key} — {meter['productName']}: {meter['meterName']} | {inventory['stages']['hybrid']['resources'].get(key,0)} | {meter['retailPrice']:.4f} | {meter['unitOfMeasure']} / {meter['basis']} |")
    lines += ['', 'Exact meter IDs, regions, tier thresholds, units, effective dates and the pricing retrieval date are in [cost-snapshot.json](cost-snapshot.json). Quantities are in [curriculum/costs.json](../curriculum/costs.json).', '',
              'Sources: [Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices), [DNS billing and Zone 1 regions](https://azure.microsoft.com/en-us/pricing/details/dns/), [WAF capacity billing](https://learn.microsoft.com/en-us/azure/application-gateway/understanding-pricing), [Managed Disks](https://azure.microsoft.com/en-us/pricing/details/managed-disks/).', '',
              'The API may return multiple tiers or product variants with the same meter ID. Refresh exact product/region/tier combinations; do not choose the cheapest result automatically.', '']
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    choice = parser.add_mutually_exclusive_group()
    choice.add_argument('--lab')
    choice.add_argument('--stage', choices=['foundation','secure','applications','hybrid'])
    parser.add_argument('--hours', type=float, default=4)
    parser.add_argument('--optional-probes', action='store_true')
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    snapshot = json.loads((ROOT/'docs/cost-snapshot.json').read_text(encoding='utf-8'))
    inventory = json.loads((ROOT/'curriculum/costs.json').read_text(encoding='utf-8'))
    if args.lab or args.stage:
        key = args.lab or args.stage
        try: entry = inventory['labs' if args.lab else 'stages'][key]
        except KeyError: parser.error(f'Unknown lesson: {key}')
        resources = dict(entry['resources'])
        if args.optional_probes:
            for name, qty in entry.get('optional_resources', {}).items(): resources[name] = resources.get(name,0)+qty
        if key == 'TFA-040': parser.error('TFA-040 has cumulative stages; select --stage foundation|secure|applications|hybrid.')
        for name, qty in resources.items(): print(f"{name:20} {qty:>4g}  USD {line_cost(snapshot['meters'][name],qty,args.hours,snapshot):.4f}")
        print(f"{key}: {args.hours:g} hours = USD {estimate(resources,args.hours,snapshot):.2f}; snapshot {snapshot['date']}.")
        print(entry['note'])
        print('Planning estimate only; additional usage excluded. See docs/cost-estimates.md. Azure runtime unverified.')
    else:
        content = render(snapshot, inventory)
        target = ROOT/'docs/cost-estimates.md'
        if args.write: target.write_text(content,encoding='utf-8',newline='\n')
        elif args.check:
            if target.read_text(encoding='utf-8') != content: raise SystemExit('Cost tables drifted: run python tools/cost_estimate.py --write')
            print('PASS: dated cost tables match all 40 inventories, four stages and 20 selected meters.')
        else: print(content)


if __name__ == '__main__': main()
