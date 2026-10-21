# Dated course cost estimates

Retrieved **2026-10-21**, West Europe, **USD** public consumption prices. These are planning estimates, not an observed bill.

Reproduce without Azure credentials or network access: `python tools/cost_estimate.py --check`.

## Assumptions and complete fixed footprint

- VM: Windows Server B2s, no Hybrid Benefit or reservation; image OS disk assumed 128 GiB (S10 HDD in standalone labs, E10 SSD in the capstone). Verify the selected image size before deployment.
- WAF reserves one instance, hence ten capacity units. More demand increases capacity charges.
- Monthly endpoint, disk, alert and storage rates use 730 hours. DNS zones use daily billing and a 31-day pricing month: even a four-hour session includes one zone-day; crossing midnight can add another.
- Each Storage account is modelled with 1 GB Hot LRS data. Log Analytics, where configured, assumes 1 GB/day; this is a usage assumption, not a guarantee or spending limit.
- No subscription-wide free grants are deducted for logs or alerts. Global NAT/Private Link and Zone 1 DNS meters are used where the API has no West Europe row.
- Resource groups, VNets, subnets, NICs, NSGs, route tables, identity/RBAC, DCRs and Standard Key Vault have no fixed deployment fee. Their traffic, storage or API usage can incur charges.
- Excludes traffic/egress, peering, Firewall/NAT/PE data processing, DNS queries, disk I/O, Blob/Key Vault operations, extra log ingestion/retention, tax, discounts, and resources outside the declared examples. These usage-dependent charges must be added for the planned session.
- Standalone lessons exclude resources from other labs. Capstone stages include the separate backend account. Optional probes are reported separately.

## Every lesson

| Lab | Fixed/resource assumptions | 4 hours USD | 24 hours USD |
|---|---|---:|---:|
| TFA-001 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-002 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-003 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-004 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-005 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-006 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-007 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-008 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-008 optional probes | Additional VM/disks/NAT/public IPs | +0.71 | +4.28 |
| TFA-009 | 1 × nat, 1 × pip | 0.20 | 1.20 |
| TFA-010 | 1 × nat, 1 × pip, 1 × vm, 1 × hdd | 0.46 | 2.74 |
| TFA-011 | 1 × nat, 2 × pip, 1 × vm, 1 × hdd, 1 × bastion_basic | 1.24 | 7.42 |
| TFA-012 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-012 optional probes | Additional VM/disks/NAT/public IPs | +1.37 | +8.21 |
| TFA-013 | 1 × vm, 1 × hdd | 0.26 | 1.54 |
| TFA-014 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-015 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-016 | 1 × blob_gb | 0.00 | 0.00 |
| TFA-017 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-018 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-019 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-020 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-021 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-022 | 1 × dns_zone | 0.02 | 0.02 |
| TFA-023 | 1 × blob_gb, 1 × dns_zone, 1 × pe, 1 × vm, 1 × hdd, 1 × nat, 1 × pip | 0.51 | 2.99 |
| TFA-024 | 1 × vm, 1 × hdd, 1 × nat, 1 × pip | 0.46 | 2.74 |
| TFA-025 | 1 × firewall, 1 × pip, 1 × vm, 1 × hdd, 1 × log_gb | 5.77 | 34.65 |
| TFA-026 | 1 × firewall, 1 × pip, 2 × vm, 2 × hdd | 5.53 | 33.20 |
| TFA-027 | 1 × waf, 10 × waf_cu, 1 × pip, 2 × vm, 2 × hdd | 2.98 | 17.88 |
| TFA-028 | 1 × vm, 1 × hdd, 1 × nat, 1 × pip, 1 × log_gb, 1 × log_alert | 0.97 | 5.83 |
| TFA-029 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-030 | 2 × vpn, 2 × pip, 2 × vm, 2 × hdd | 2.23 | 13.40 |
| TFA-031 | 2 × vpn, 4 × pip, 2 × vm, 2 × hdd, 1 × dns_in, 1 × dns_out, 1 × dns_rules, 1 × dns_zone, 1 × pe, 1 × blob_gb, 2 × nat | 4.68 | 27.97 |
| TFA-032 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-033 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-034 | 2 × vm, 2 × hdd, 1 × dns_zone, 1 × nat, 1 × pip | 0.73 | 4.29 |
| TFA-035 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-036 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-037 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-038 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-039 | No fixed-price deployment in default root | 0.00 | 0.00 |
| TFA-040 | See cumulative stages | See stages | See stages |

## Cumulative capstone stages

| Stage | 4 hours USD | 24 hours USD |
|---|---:|---:|
| foundation | 0.05 | 0.05 |
| secure | 7.73 | 46.16 |
| applications | 11.11 | 66.43 |
| hybrid | 14.31 | 85.61 |

These are cumulative totals: do not add them unless you actually keep each stage deployed for a separate session.

| Meter key | Hybrid quantity | USD per original unit | Original unit / model |
|---|---:|---:|---|
| firewall — Azure Firewall: Standard Deployment | 1 | 1.2500 | 1 Hour / hour |
| bastion_standard — Azure Bastion: Standard Gateway | 1 | 0.2900 | 1 Hour / hour |
| bastion_basic — Azure Bastion: Basic Gateway | 0 | 0.1900 | 1 Hour / hour |
| waf — Application Gateway WAF v2: Standard Fixed Cost | 1 | 0.4680 | 1/Hour / hour |
| waf_cu — Application Gateway WAF v2: Standard Capacity Units | 10 | 0.0144 | 1/Hour / hour |
| vpn — VPN Gateway: VpnGw1AZ | 2 | 0.2100 | 1 Hour / hour |
| pip — IP Addresses: Standard IPv4 Static Public IP | 6 | 0.0050 | 1 Hour / hour |
| nat — NAT Gateway: Standard Gateway | 1 | 0.0450 | 1 Hour / hour |
| pe — Virtual Network Private Link: Standard Private Endpoint | 2 | 0.0100 | 1 Hour / hour |
| vm — Virtual Machines BS Series Windows: B2s | 4 | 0.0560 | 1 Hour / hour |
| ssd — Standard SSD Managed Disks: E10 LRS Disk | 4 | 9.6000 | 1/Month / month |
| hdd — Standard HDD Managed Disks: S10 LRS Disk | 0 | 5.8880 | 1/Month / month |
| dns_in — Azure DNS: Private Resolver Inbound Endpoint | 1 | 180.0000 | 1 / month |
| dns_out — Azure DNS: Private Resolver Outbound Endpoint | 1 | 180.0000 | 1 / month |
| dns_rules — Azure DNS: Private Resolver DNS Forwarding Ruleset | 1 | 2.5000 | 1 / month |
| dns_zone — Azure DNS: Private Zone | 3 | 0.5000 | 1 / month_daily |
| blob_gb — General Block Blob v2: Hot LRS Data Stored | 2 | 0.0196 | 1 GB/Month / month |
| log_gb — Log Analytics: Analytics Logs Data Ingestion | 1 | 2.9900 | 1 GB / usage_daily |
| log_alert — Azure Monitor: Alerts System Log Monitored at 1 Minute Frequency | 0 | 3.0000 | 1/Month / month |
| metric_alert — Azure Monitor: Alerts Metric Monitored | 1 | 0.1000 | 1/Month / month |

Exact meter IDs, regions, tier thresholds, units, effective dates and the pricing retrieval date are in [cost-snapshot.json](cost-snapshot.json). Quantities are in [curriculum/costs.json](../curriculum/costs.json).

Sources: [Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices), [DNS billing and Zone 1 regions](https://azure.microsoft.com/en-us/pricing/details/dns/), [WAF capacity billing](https://learn.microsoft.com/en-us/azure/application-gateway/understanding-pricing), [Managed Disks](https://azure.microsoft.com/en-us/pricing/details/managed-disks/).

The API may return multiple tiers or product variants with the same meter ID. Refresh exact product/region/tier combinations; do not choose the cheapest result automatically.
