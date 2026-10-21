# Terraform and Azure glossary

| Term | Meaning in this course |
|---|---|
| Tenant | The Microsoft Entra identity boundary. It is not a resource group. |
| Subscription | Azure billing/governance scope selected explicitly by ID. |
| Resource group | A lifecycle grouping for Azure resources; its location does not force every resource into that region. |
| Provider | Terraform plugin translating resource configuration into service API calls. |
| State | Terraform's bindings between resource addresses and remote objects; sensitive operational data. |
| Plan | Proposed actions for a specific configuration, state and input set. Saved plans can contain secrets. |
| Backend | State storage and locking configuration, separate from provider configuration. |
| Module | Reusable Terraform resources with an explicit input/output contract. |
| Drift | Remote behavior/configuration differing from Terraform's intended configuration. |
| CIDR | Prefix notation defining an address range. Non-overlap is required across connected networks. |
| NSG | Stateful network filtering associated with subnets or NICs; priorities and default rules matter. |
| ASG | Logical grouping of NICs for NSG rules. It is not a routing device. |
| UDR | User-defined route. Longest-prefix selection still matters. |
| Peering | Direct private connectivity between VNets; it is not automatically transitive. |
| Gateway transit | Use of a hub gateway by a peered spoke with matching peering settings. |
| NAT | Address translation; explicit internet outbound is different from a private VPN route. |
| Private endpoint | A private NIC/IP path to a specific service subresource; DNS must point clients at it. |
| Private DNS zone | Authoritative records visible through linked networks/resolver paths. |
| DNS forwarding | Sending a query to another resolver; it does not create network connectivity. |
| WAF | HTTP application request inspection; separate from generic network firewall rules. |
| Managed identity | Azure resource identity that obtains Entra tokens without a stored application password. |
| OIDC federation | Trust in short-lived GitHub identity assertions to obtain Azure credentials. |
| RBAC | Authorization at a defined scope; management-plane and data-plane roles differ. |
| AMA / DCR | Azure Monitor Agent and Data Collection Rule for supported guest telemetry. |
| IPsec / IKE | Tunnel protection and negotiation for the VPN simulation. |
| BGP | Route exchange protocol; taught conceptually without requiring advanced BGP operations in v1. |
