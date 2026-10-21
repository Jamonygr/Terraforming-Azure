mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "22222222-2222-2222-2222-222222222222"
    }
  }
}

variables {
  subscription_id      = "22222222-2222-2222-2222-222222222222"
  operator_cidrs       = ["203.0.113.10/32"]
  admin_password       = "Example-Only-Password-77!"
  certificate_path     = "tests/fixtures/certificate.fixture"
  certificate_password = "Mock-Certificate-Password-77!"
  vpn_shared_key       = "Mock-IPsec-Shared-Key-77!"
}

run "foundation" {
  command = plan
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
  command = plan
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
  command = plan
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
  command = plan
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
