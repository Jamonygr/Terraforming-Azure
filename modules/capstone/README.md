# Capstone module

One reusable module suite for [TFA-040](../../labs/TFA-040/README.md). This module is
the final reference, introduced after learners have built its parts directly.
It is not a production landing-zone accelerator.

## Stable lifecycle

`stage` is exactly `foundation`, `secure`, `applications`, or `hybrid`. Each stage
includes the earlier stages. A single root/state owns the architecture; advancing
uses normal whole-root plans. Selecting an earlier stage removes later resources.
Resource addresses use stable network/VM keys rather than unrelated copies.

| Stage | Added resources |
|---|---|
| foundation | Five VNets, reserved/delegated subnets, NSGs, hub-spoke peerings, private zones, workspace/action group |
| secure | Standard Firewall+policy/DNS proxy, Standard Bastion/native-client access, resolver inbound, workload DNS/UDRs |
| applications | Two private Windows/IIS VMs, ops VM, WAF_v2 public HTTPS, two PEs, private Storage/Key Vault, managed-identity roles, AMA/DCR/DCE/alert/diagnostics |
| hybrid | Two VpnGw1AZ gateways/connections, gateway-transit peerings, specific gateway UDRs, Windows DNS/client, resolver outbound/ruleset, on-premises-only NAT |

## Inputs and caller responsibilities

Required inputs: `operator_cidrs` and a sensitive `admin_password`. The root also
requires `subscription_id` and configures AzureRM `=4.77.0` with
`features.storage.data_plane_available = false`, deliberately avoiding private
Storage data-plane operations from the public runner. Use Entra-authenticated
remote state, keep credentials out of Git, and pre-register the required resource
providers as documented by the course.

Defaults: location `westeurope`, prefix `tfazure`, environment `lab`, stage
`foundation`, and five distinct `/16` private ranges. Inputs validate distinct
network blocks, naming limits, exact stages and specific operator CIDRs.
`address_plan`, `tags` and optional `alert_email` customize the lab.

`certificate_path` and `certificate_password` are sensitive nullable inputs,
required only for applications/hybrid. The existing local PFX must match
`app.terraforming-azure.test`. It is loaded into state. `vpn_shared_key` is sensitive,
nullable until hybrid, and then requires 16+ characters. Password/PKI complexity
and actual Azure certificate validation are Azure runtime checks.

Outputs expose the resource group, subnet prefixes/IDs, VM names/IDs/private IPs,
NICs, resolver/firewall IPs, ingress IP/name/hostname, private service names,
workspace and VPN connection names. No credential output is exposed.
`traffic_contract` derives its values from managed NIC, route, association, peering
and service resources. `evidence_targets` supplies non-secret resource names and
IDs; `private_endpoint_ips` reports actual service-connection addresses. These are
configuration evidence; live verification must inspect
effective routes, actual HTTP/DNS behavior and service logs.

## Important implementation boundaries

- Application Gateway and its backends share the app VNet, with separate subnets.
  Only workload subnets inherit the Firewall default route. AppGW receives direct
  public responses/control-plane routes; IIS returns to its same-VNet gateway.
- Data-spoke PE policies are enabled. Specific prefix UDRs plus Firewall HTTPS
  application rules inspect PE access and provide SNAT return symmetry.
- No spoke-spoke or on-premises peering exists. Gateway transit is enabled only
  after both hybrid gateways exist. GatewaySubnet uses specific spoke routes,
  no default-route UDR, no NSG. Firewall retains gateway routes.
- Spoke DNS → Firewall proxy → resolver inbound → hub-linked private zones. The
  hub outbound ruleset forwards only the corp zone over VPN. Windows DNS forwards
  original Azure service namespaces back to inbound; there is no self-forwarding
  Azure zone rule in the hub ruleset. The outbound endpoint/corporate DNS pair uses
  a direct VPN path, with no Firewall UDR or Firewall rule. Its corporate NSG
  allows DNS from the outbound resolver subnet; do not expect Firewall logs for it.
- corp01 boots on Azure DNS before its DNS role is installed, then changes its own
  DNS client and the VNet setting. The on-premises NAT provides extension/AMA
  Internet egress and does not bypass more-specific private VPN paths.
- Terraform creates no private blob containers, blobs or secrets. The included
  [private seed/probe helper](../../labs/TFA-040/scripts/Initialize-PrivateData.ps1)
  uses the operations VM identity. This preserves a deployable public control
  plane while the data plane remains private.
- Windows Server 2022 Azure Edition image version is `latest` for security fixes.
  VM size is B2s for teaching. The lab is single-region and intentionally excludes
  multi-region DR, domain joins, real on-premises appliances, Premium TLS
  inspection and production certificate automation.

## Offline tests

```powershell
terraform init -backend=false -lockfile=readonly
terraform validate
terraform test
```

The mock-provider suite applies all stages in memory and checks actual resource
relationships using distinct fabricated IDs:
counts, private NICs/services, WAF prevention/backends, PE policies, explicit routes,
gateway transit and DNS forwarding. It makes no Azure API calls and cannot certify
cloud deployability or traffic behavior. TFA-040 provides the live acceptance work.

The repository mutation runner copies this module to an isolated temporary root
and proves that five changes fail assertions: adding a workload public IP,
associating the app route table with the WAF subnet, disabling PE route policies,
widening Firewall rule sources, and removing a required return route. It never
modifies the working module. Run `python tools/test_capstone_mutations.py` from the
repository root with contributor Python 3.12+.
