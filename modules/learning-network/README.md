# learning-network

This intentionally small teaching module creates one resource group, one VNet,
and private subnets from stable map keys. Learners build the same resources
directly in TFA-007 before introducing this abstraction in TFA-017.

The calling root owns authentication, the provider version pin, backend, and
deployment identity. This child module never configures its own provider.

| Input | Contract |
|---|---|
| `name_prefix` | Required stable lowercase identity, 3–20 characters. |
| `location` | Required Azure region. Changing location may replace resources. |
| `tags` | Optional `map(string)`, propagated to taggable resources. |
| `address_space` | `list(string)` of IPv4 CIDRs; defaults to `10.20.0.0/16`. |
| `subnets` | Required nonempty `map(string)`, subnet name to IPv4 CIDR. |

Outputs are `resource_group_name`, `vnet_id`, `vnet_name`, and `subnet_ids`.
The last output preserves the input map keys; consumers should use
`module.network.subnet_ids["web"]` rather than internal resource addresses.

CIDR syntax is checked locally. Azure validates containment and overlap during
deployment: this learning module does not implement a general IPAM engine.
All subnets explicitly disable default outbound access. Add a deliberate egress
design before expecting a private VM to reach public package repositories.

Run `terraform init -backend=false` and `terraform test` from this folder. Tests
mock AzureRM and check names, key stability, tags, explicit outbound posture,
and rejected inputs. They verify Terraform behavior, not Azure connectivity.
