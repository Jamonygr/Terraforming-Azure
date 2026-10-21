mock_provider "azurerm" { source = "../../modules/capstone/tests/mocks" }

variables {
  subscription_id      = "22222222-2222-2222-2222-222222222222"
  operator_cidrs       = ["203.0.113.10/32"]
  admin_password       = "Example-Only-Password-77!"
  certificate_path     = "tests/fixtures/certificate.fixture"
  certificate_password = "Mock-Certificate-Password-77!"
  vpn_shared_key       = "Mock-IPsec-Shared-Key-77!"
}

run "foundation" {
  command = apply
  variables { stage = "foundation" }
  assert {
    condition     = output.traffic_contract.windows_vm_count == 0 && output.traffic_contract.vpn_gateway_count == 0
    error_message = "Foundation must not create VMs or VPN gateways."
  }
  assert {
    condition     = output.firewall_private_ip == null && output.app_gateway_name == null
    error_message = "Foundation must not create chargeable firewall or WAF services."
  }
}

run "secure" {
  command = apply
  variables { stage = "secure" }
  assert {
    condition     = output.traffic_contract.firewall_sku == "Standard" && output.traffic_contract.windows_vm_count == 0
    error_message = "Secure stage adds Standard firewall before workloads."
  }
  assert {
    condition     = output.resolver_inbound_ip == "10.0.1.4"
    error_message = "Resolver must have a predictable, non-reserved static inbound IP."
  }
}

run "applications" {
  command = apply
  variables { stage = "applications" }
  assert {
    condition     = output.traffic_contract.windows_vm_count == 3 && output.traffic_contract.vpn_gateway_count == 0
    error_message = "Applications stage needs two IIS VMs and one operations VM, without VPN."
  }
  assert {
    condition     = !output.traffic_contract.ingress_forced_tunnel && output.traffic_contract.public_vm_count == 0
    error_message = "WAF subnet must stay outside generic forced tunnel and all VMs must be private."
  }
}

run "hybrid" {
  command = apply
  variables { stage = "hybrid" }
  assert {
    condition     = output.traffic_contract.windows_vm_count == 4 && output.traffic_contract.vpn_gateway_count == 2
    error_message = "Hybrid requires the corp VM and both Azure VPN gateways."
  }
  assert {
    condition     = length(output.vpn_connection_names) == 2 && output.traffic_contract.spoke_direct_peerings == 0
    error_message = "Hybrid must use reciprocal VPN connections, with no direct spoke-to-spoke peers."
  }
}

run "reject_invalid_stage" {
  command = plan
  variables { stage = "full" }
  expect_failures = [var.stage]
}

run "reject_world_open_operator" {
  command = plan
  variables { operator_cidrs = ["0.0.0.0/0"] }
  expect_failures = [var.operator_cidrs]
}

run "reject_missing_hybrid_secret" {
  command = plan
  variables {
    stage          = "hybrid"
    vpn_shared_key = null
  }
  expect_failures = [var.vpn_shared_key]
}

# Keep identities distinct so relationship assertions can detect wrong associations.
override_resource {
  target = module.capstone.azurerm_virtual_network.network["hub"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/hub" }
}
override_resource {
  target = module.capstone.azurerm_virtual_network.network["app"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/app" }
}
override_resource {
  target = module.capstone.azurerm_virtual_network.network["data"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/data" }
}
override_resource {
  target = module.capstone.azurerm_virtual_network.network["operations"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/operations" }
}
override_resource {
  target = module.capstone.azurerm_virtual_network.network["onprem"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/onprem" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["firewall"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/AzureFirewallSubnet" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["bastion"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/AzureBastionSubnet" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["gateway"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/GatewaySubnet" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["dns_in"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/dns_in" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["dns_out"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/dns_out" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["ingress"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/ingress" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["app"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/app" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["data"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/data" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["operations"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/operations" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["corp"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/corp" }
}
override_resource {
  target = module.capstone.azurerm_subnet.subnet["remote_gw"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/onprem/subnets/GatewaySubnet" }
}
override_resource {
  target = module.capstone.azurerm_route_table.workload["app"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/routeTables/app" }
}
override_resource {
  target = module.capstone.azurerm_route_table.workload["data"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/routeTables/data" }
}
override_resource {
  target = module.capstone.azurerm_route_table.workload["operations"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/routeTables/operations" }
}

override_resource {
  target = module.capstone.azurerm_virtual_network_gateway.vpn["hub"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworkGateways/hub" }
}

override_resource {
  target = module.capstone.azurerm_virtual_network_gateway.vpn["onprem"]
  values = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworkGateways/onprem" }
}

run "reject_noncanonical_world_route" {
  command = plan
  variables { operator_cidrs = ["203.0.113.1/0"] }
  expect_failures = [var.operator_cidrs]
}
run "reject_operator_host_bits" {
  command = plan
  variables { operator_cidrs = ["203.0.113.10/24"] }
  expect_failures = [var.operator_cidrs]
}
run "reject_malformed_operator" {
  command = plan
  variables { operator_cidrs = ["999.1.2.3/32"] }
  expect_failures = [var.operator_cidrs]
}
run "accept_canonical_operator_ranges" {
  command = plan
  variables {
    stage          = "foundation"
    operator_cidrs = ["203.0.113.10/32", "198.51.100.0/24"]
  }
  assert {
    condition     = output.stage == "foundation"
    error_message = "Canonical operator addresses and corporate ranges must remain supported."
  }
}

run "reject_zero_padded_prefix" {
  command = plan
  variables { operator_cidrs = ["128.0.0.0/01"] }
  expect_failures = [var.operator_cidrs]
}
run "reject_ipv6_operator" {
  command = plan
  variables { operator_cidrs = ["2001:db8::/64"] }
  expect_failures = [var.operator_cidrs]
}
