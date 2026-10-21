mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = { tenant_id = "11111111-1111-1111-1111-111111111111" }
  }
}

variables {
  operator_cidrs       = ["203.0.113.10/32"]
  admin_password       = "Example-Only-Password-77!"
  certificate_path     = "../../labs/TFA-040/tests/fixtures/certificate.fixture"
  certificate_password = "Mock-Certificate-Password-77!"
  vpn_shared_key       = "Mock-IPsec-Shared-Key-77!"
}

run "foundation_resources" {
  command = plan
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
  command = plan
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
  command = plan
  variables { stage = "applications" }
  assert {
    condition     = length(azurerm_windows_virtual_machine.vm) == 3 && alltrue([for nic in azurerm_network_interface.vm : nic.ip_configuration[0].public_ip_address_id == null])
    error_message = "Applications stage must create three private-only Windows VMs."
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
  command = plan
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
