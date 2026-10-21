# Private Windows VM learning pattern

This small shared module makes the advanced labs independent without copying NIC/VM setup into every root. Read it when a lesson references it: it is executable infrastructure, not hidden scaffolding.

It creates one private NIC, one B2s Windows Server 2022 Azure Edition VM with system-assigned identity and managed boot diagnostics, and optionally one Custom Script Extension. It never creates a public IP or an inbound RDP rule. The calling lab owns subnets, NSGs, explicit outbound connectivity, routes, user-assigned identity permissions, and cost/cleanup.

Required inputs are name, resource_group_name, location, subnet_id, and sensitive admin_password. Optional inputs are private_ip_address, bootstrap_command, identity_ids, and tags. identity_ids attaches approved user-assigned identities in addition to the system identity. Bootstrap commands must contain only non-secret setup instructions: public extension settings are visible to readers. Never put a password, token, or secret value into bootstrap_command.

Outputs expose VM ID/name, NIC ID, private IP, and system identity principal ID. The administrator password remains in Terraform state even though it is marked sensitive. The Windows image version is latest for a learning sandbox; production reproducibility would require a deliberately pinned tested image version.
