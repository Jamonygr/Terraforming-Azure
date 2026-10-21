# Troubleshooting by evidence

Start with the selected lesson's expected result. Record the exact command,
resource ID, timestamp and sanitized error. Change one cause at a time and
retest. Never paste state, tokens, PFX data or passwords into an issue.

## Terraform initialization or validation

Check `terraform version` and the pinned AzureRM version. Use `terraform init
-backend=false -lockfile=readonly` only for static validation; it neither checks
Azure permissions nor proves resource availability. A lock mismatch can mean a
different provider selection or corrupted shared cache: verify the release and
checksums, then recreate only the affected local cache, preserving state.

## Authentication and backend access

Compare explicit tenant/subscription IDs with `az account show`. A successful
Azure resource-manager operation does not prove Storage data-plane authorization.
Backend access needs Entra authentication and the scoped Blob Data Contributor
role. Allow RBAC propagation time. Do not switch to access keys to hide a role
problem. An OIDC subject must exactly match the configured repository/environment.

## Guest bootstrap and extensions

Inspect VM provisioning state and extension status before testing IIS. Confirm
the subnet has explicit outbound access for required platform/agent endpoints.
An NSG allow rule does not create egress. Use Run Command for private probes;
opening public RDP is not the repair. Check Windows Firewall/service state too.

## DNS fails or returns a public address

Run `Resolve-DnsName <original-service-name>` inside the actual source VM. Check
the configured DNS server, the private zone link, endpoint zone group and
conditional forwarding suffix. A laptop outside the private network is not a
valid private DNS probe. Confirm UDP and TCP53 paths when testing hybrid DNS.
Avoid ruleset loops forwarding a hub's own private zones back to its inbound IP.

## TCP fails after DNS succeeds

Inspect source effective routes, NIC NSGs, Firewall logs and destination service
health. Compare longest prefixes before blaming the default route. Verify both
forward and return paths. Check gateway propagation and forwarded-traffic flags.
A ping failure alone does not prove HTTP or RDP is unavailable.

## Application Gateway is unhealthy

Read backend health and probe host/path/port before editing WAF rules. Confirm
IIS responds privately and has no blocked NSG/Windows Firewall path. Keep the
gateway subnet's return/control-plane route separate from workload forced egress.
For the lab certificate, use the documented hostname and explicit test-client
self-signed trust; do not disable TLS validation in production code.

## VPN is connected but traffic fails

Tunnel status proves negotiation, not workload reachability. Inspect traffic
counters, non-overlapping prefixes, specific GatewaySubnet routes, spoke UDRs,
Firewall rules and DNS. Remember the corporate simulation's internet NAT is not
the Azure private routing path.

## Recovery and cleanup

Read a fresh plan against the same state after an interrupted apply. Import
or move ownership only after checking the actual object ID. Never force-unlock
someone else's active operation. Destroy dependants before backend storage and
read TFA-038 before restoring a previous state version.
