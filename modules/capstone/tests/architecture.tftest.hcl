mock_provider "azurerm" { source = "tests/mocks" }

variables {
  operator_cidrs       = ["203.0.113.10/32"]
  admin_password       = "Example-Only-Password-77!"
  certificate_path     = "../../labs/TFA-040/tests/fixtures/certificate.fixture"
  certificate_password = "Mock-Certificate-Password-77!"
  vpn_shared_key       = "Mock-IPsec-Shared-Key-77!"
}

run "foundation_resources" {
  command = apply
  variables { stage = "foundation" }
  assert {
    condition     = length(azurerm_virtual_network.network) == 5 && length(azurerm_virtual_network_peering.hub_to_spoke) == 3 && length(azurerm_virtual_network_peering.spoke_to_hub) == 3
    error_message = "Topology must contain five VNets with only three reciprocal hub-spoke peerings."
  }
  assert {
    condition     = length(azurerm_firewall.hub) == 0 && length(azurerm_windows_virtual_machine.vm) == 0 && length(azurerm_application_gateway.ingress) == 0
    error_message = "Foundation must omit the chargeable compute/security services."
  }
}

run "secure_routing" {
  command = apply
  variables { stage = "secure" }
  assert {
    condition     = azurerm_firewall.hub[0].sku_tier == "Standard" && azurerm_firewall_policy.hub[0].dns[0].proxy_enabled && azurerm_bastion_host.hub[0].tunneling_enabled
    error_message = "Standard Firewall DNS proxy and native-client Bastion must be configured."
  }
  assert {
    condition     = alltrue([for rt in azurerm_route_table.workload : !rt.bgp_route_propagation_enabled]) && length(azurerm_route.private) == 9
    error_message = "Workloads must use explicit private-prefix firewall routes without gateway propagation bypasses."
  }
  assert {
    condition     = !contains(keys(azurerm_subnet_route_table_association.workload), "ingress") && azurerm_subnet.subnet["data"].private_endpoint_network_policies == "Enabled"
    error_message = "Ingress must not inherit forced tunneling and PE subnet route policies must be enabled."
  }
}

run "application_boundaries" {
  command = apply
  variables { stage = "applications" }
  assert {
    condition     = length(azurerm_windows_virtual_machine.vm) == 3
    error_message = "Applications stage must create three Windows VMs."
  }
  assert {
    condition     = alltrue([for nic in azurerm_network_interface.vm : nic.ip_configuration[0].public_ip_address_id == null])
    error_message = "Each workload NIC must remain private-only."
  }
  assert {
    condition     = !azurerm_storage_account.data[0].public_network_access_enabled && !azurerm_key_vault.data[0].public_network_access_enabled && length(azurerm_private_endpoint.data) == 2
    error_message = "Both data services must be private-only and have private endpoints."
  }
  assert {
    condition     = azurerm_application_gateway.ingress[0].sku[0].name == "WAF_v2" && length(one(azurerm_application_gateway.ingress[0].backend_address_pool).ip_addresses) == 2 && one(azurerm_web_application_firewall_policy.ingress[0].policy_settings).mode == "Prevention"
    error_message = "Public ingress must use WAF prevention with both private IIS backends."
  }
}

run "hybrid_symmetry" {
  command = apply
  variables { stage = "hybrid" }
  assert {
    condition     = length(azurerm_virtual_network_gateway.vpn) == 2 && length(azurerm_virtual_network_gateway_connection.vpn) == 2 && length(azurerm_windows_virtual_machine.vm) == 4
    error_message = "Hybrid needs two gateways, reciprocal connections, and corp01."
  }
  assert {
    condition     = length(azurerm_route.gateway_to_spokes) == 3 && alltrue([for route in azurerm_route.gateway_to_spokes : route.address_prefix != "0.0.0.0/0"])
    error_message = "GatewaySubnet must route each spoke through Firewall without a default-route UDR."
  }
  assert {
    condition     = alltrue([for peer in azurerm_virtual_network_peering.spoke_to_hub : peer.use_remote_gateways]) && alltrue([for peer in azurerm_virtual_network_peering.hub_to_spoke : peer.allow_gateway_transit])
    error_message = "Both directions of peering must enable gateway transit."
  }
  assert {
    condition     = azurerm_private_dns_resolver_forwarding_rule.corp[0].domain_name == "corp.terraforming-azure.test." && one(azurerm_private_dns_resolver_forwarding_rule.corp[0].target_dns_servers).ip_address == "192.168.1.4" && length(azurerm_subnet_nat_gateway_association.onprem) == 1
    error_message = "Hybrid must forward only the corp namespace to corp01 and provide explicit simulation Internet egress."
  }
}

run "inspect_real_relationships" {
  command = apply
  variables { stage = "hybrid" }
  assert {
    condition     = !output.traffic_contract.ingress_forced_tunnel && output.traffic_contract.public_vm_count == 0 && output.traffic_contract.spoke_direct_peerings == 0 && !output.traffic_contract.gateway_default_route
    error_message = "CONTRACT: no public VM, direct-spoke peering, ingress forced tunnel or gateway default route."
  }
  assert {
    condition     = alltrue([for key, association in azurerm_subnet_route_table_association.workload : association.subnet_id == azurerm_subnet.subnet[key].id && association.route_table_id == azurerm_route_table.workload[key].id]) && length(azurerm_subnet_route_table_association.workload) == 3
    error_message = "ASSOCIATION: each workload table must stay on its intended subnet; ingress is separate."
  }
  assert {
    condition     = alltrue([for key, route in azurerm_route.default : route.address_prefix == "0.0.0.0/0" && route.next_hop_type == "VirtualAppliance" && route.next_hop_in_ip_address == one(azurerm_firewall.hub[0].ip_configuration).private_ip_address]) && alltrue([for key, route in azurerm_route.private : route.address_prefix == local.networks[split("-", key)[1]] && route.next_hop_type == "VirtualAppliance" && route.next_hop_in_ip_address == one(azurerm_firewall.hub[0].ip_configuration).private_ip_address]) && length(azurerm_route.private) == 9
    error_message = "ROUTES: all explicit forward/return prefixes must traverse the actual Firewall address."
  }
  assert {
    condition     = azurerm_subnet.subnet["data"].private_endpoint_network_policies == "Enabled" && azurerm_network_security_rule.private_data.source_address_prefix == local.subnets.firewall.prefix && azurerm_network_security_rule.private_data.destination_port_range == "443" && azurerm_network_security_rule.private_data.access == "Allow"
    error_message = "PRIVATE_DATA: enable PE policies and allow HTTPS only from the Firewall subnet."
  }
  assert {
    condition     = alltrue([for rule in one(azurerm_firewall_policy_rule_collection_group.lab[0].network_rule_collection).rule : toset(rule.source_addresses) == toset([local.subnets.operations.prefix, local.subnets.corp.prefix]) && toset(rule.destination_addresses) == toset([local.subnets.app.prefix]) && toset(rule.destination_ports) == toset(["80"]) && toset(rule.protocols) == toset(["TCP"])])
    error_message = "FIREWALL: the IIS network rule must preserve approved sources, destination and TCP/80."
  }
  assert {
    condition     = alltrue([for key, role in azurerm_role_assignment.blob : role.scope == azurerm_storage_account.data[0].id && role.principal_id == one(azurerm_windows_virtual_machine.vm[key].identity).principal_id && role.role_definition_name == (key == "ops01" ? "Storage Blob Data Contributor" : "Storage Blob Data Reader")]) && alltrue([for key, role in azurerm_role_assignment.vault : role.scope == azurerm_key_vault.data[0].id && role.principal_id == one(azurerm_windows_virtual_machine.vm[key].identity).principal_id && role.role_definition_name == (key == "ops01" ? "Key Vault Secrets Officer" : "Key Vault Secrets User")])
    error_message = "IDENTITY: scope each data role to its service and intended VM identity; only ops can seed."
  }
  assert {
    condition     = azurerm_bastion_host.hub[0].sku == "Standard" && azurerm_bastion_host.hub[0].ip_connect_enabled && azurerm_bastion_host.hub[0].tunneling_enabled
    error_message = "BASTION: Standard IP-based connectivity is required for the corporate VM over VPN."
  }
  assert {
    condition     = one(azurerm_firewall_policy.hub[0].dns).proxy_enabled && one(azurerm_firewall_policy.hub[0].dns).servers == tolist([local.resolver_ip]) && alltrue([for settings in azurerm_virtual_network_dns_servers.spokes : settings.dns_servers == tolist([one(azurerm_firewall.hub[0].ip_configuration).private_ip_address])])
    error_message = "DNS: spoke settings must point to Firewall proxy and its upstream to resolver inbound."
  }
  assert {
    condition     = alltrue([for key, connection in azurerm_virtual_network_gateway_connection.vpn : connection.virtual_network_gateway_id == azurerm_virtual_network_gateway.vpn[key].id && connection.peer_virtual_network_gateway_id == azurerm_virtual_network_gateway.vpn[key == "hub" ? "onprem" : "hub"].id]) && alltrue([for key, route in azurerm_route.gateway_to_spokes : route.address_prefix == local.networks[key] && route.next_hop_in_ip_address == one(azurerm_firewall.hub[0].ip_configuration).private_ip_address])
    error_message = "HYBRID: reciprocal gateway identities and inspected spoke return routes must agree."
  }
}

# Keep identities distinct so relationship assertions can detect wrong associations.
override_resource {
  target = azurerm_virtual_network.network["hub"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/hub" }
}
override_resource {
  target = azurerm_virtual_network.network["app"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/app" }
}
override_resource {
  target = azurerm_virtual_network.network["data"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/data" }
}
override_resource {
  target = azurerm_virtual_network.network["operations"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/operations" }
}
override_resource {
  target = azurerm_virtual_network.network["onprem"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/onprem" }
}
override_resource {
  target = azurerm_subnet.subnet["firewall"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/AzureFirewallSubnet" }
}
override_resource {
  target = azurerm_subnet.subnet["bastion"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/AzureBastionSubnet" }
}
override_resource {
  target = azurerm_subnet.subnet["gateway"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/GatewaySubnet" }
}
override_resource {
  target = azurerm_subnet.subnet["dns_in"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/dns_in" }
}
override_resource {
  target = azurerm_subnet.subnet["dns_out"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/dns_out" }
}
override_resource {
  target = azurerm_subnet.subnet["ingress"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/ingress" }
}
override_resource {
  target = azurerm_subnet.subnet["app"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/app" }
}
override_resource {
  target = azurerm_subnet.subnet["data"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/data" }
}
override_resource {
  target = azurerm_subnet.subnet["operations"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/operations" }
}
override_resource {
  target = azurerm_subnet.subnet["corp"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/corp" }
}
override_resource {
  target = azurerm_subnet.subnet["remote_gw"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/onprem/subnets/GatewaySubnet" }
}
override_resource {
  target = azurerm_route_table.workload["app"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/routeTables/app" }
}
override_resource {
  target = azurerm_route_table.workload["data"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/routeTables/data" }
}
override_resource {
  target = azurerm_route_table.workload["operations"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/routeTables/operations" }
}

override_resource {
  target = azurerm_virtual_network_gateway.vpn["hub"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworkGateways/hub" }
}

override_resource {
  target = azurerm_virtual_network_gateway.vpn["onprem"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworkGateways/onprem" }
}

override_resource {
  target = azurerm_windows_virtual_machine.vm["iis01"]
  values = {
    id       = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Compute/virtualMachines/iis01"
    identity = { principal_id = "33333333-3333-3333-3333-000000000001", tenant_id = "44444444-4444-4444-4444-444444444444" }
  }
}

override_resource {
  target = azurerm_windows_virtual_machine.vm["iis02"]
  values = {
    id       = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Compute/virtualMachines/iis02"
    identity = { principal_id = "33333333-3333-3333-3333-000000000002", tenant_id = "44444444-4444-4444-4444-444444444444" }
  }
}

override_resource {
  target = azurerm_windows_virtual_machine.vm["ops01"]
  values = {
    id       = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Compute/virtualMachines/ops01"
    identity = { principal_id = "33333333-3333-3333-3333-000000000003", tenant_id = "44444444-4444-4444-4444-444444444444" }
  }
}

override_resource {
  target = azurerm_windows_virtual_machine.vm["corp01"]
  values = {
    id       = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Compute/virtualMachines/corp01"
    identity = { principal_id = "33333333-3333-3333-3333-000000000004", tenant_id = "44444444-4444-4444-4444-444444444444" }
  }
}
