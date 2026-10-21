mock_provider "azurerm" {
  override_during = plan
  mock_data "azurerm_client_config" {
    defaults = { tenant_id = "11111111-1111-1111-1111-111111111111", client_id = "11111111-1111-1111-1111-111111111111", object_id = "11111111-1111-1111-1111-111111111111", subscription_id = "11111111-1111-1111-1111-111111111111" }
  }
  mock_resource "azurerm_resource_group" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock" }
  }
  mock_resource "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/mock" }
  }
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/mock/subnets/mock" }
  }
  mock_resource "azurerm_network_interface" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/networkInterfaces/mock", private_ip_address = "10.27.1.4" }
  }
  mock_resource "azurerm_windows_virtual_machine" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Compute/virtualMachines/mock", identity = { principal_id = "11111111-1111-1111-1111-111111111111", tenant_id = "11111111-1111-1111-1111-111111111111" } }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mock", client_id = "11111111-1111-1111-1111-111111111111", principal_id = "11111111-1111-1111-1111-111111111111", tenant_id = "11111111-1111-1111-1111-111111111111" }
  }
  mock_resource "azurerm_key_vault" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.KeyVault/vaults/mock", vault_uri = "https://mock.vault.azure.net/" }
  }
  mock_resource "azurerm_storage_account" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Storage/storageAccounts/mock" }
  }
  mock_resource "azurerm_private_dns_zone" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net" }
  }
  mock_resource "azurerm_public_ip" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/publicIPAddresses/mock", ip_address = "203.0.113.10" }
  }
  mock_resource "azurerm_firewall_policy" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/firewallPolicies/mock" }
  }
  mock_resource "azurerm_firewall" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/azureFirewalls/mock", ip_configuration = { private_ip_address = "10.26.0.4" } }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.OperationalInsights/workspaces/mock", workspace_id = "11111111-1111-1111-1111-111111111111" }
  }
  mock_resource "azurerm_monitor_data_collection_rule" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Insights/dataCollectionRules/mock" }
  }
  mock_resource "azurerm_virtual_network_gateway" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworkGateways/mock" }
  }
  mock_resource "azurerm_private_dns_resolver" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/dnsResolvers/mock" }
  }
  mock_resource "azurerm_web_application_firewall_policy" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies/mock" }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/networkSecurityGroups/mock" }
  }
  mock_resource "azurerm_nat_gateway" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/natGateways/mock" }
  }
  mock_resource "azurerm_route_table" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/routeTables/mock" }
  }
  mock_resource "azurerm_policy_definition" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/policyDefinitions/mock" }
  }
}
variables {
  subscription_id = "11111111-1111-1111-1111-111111111111"
  admin_password  = "OfflineMockOnly!2026"
}
run "architecture_contract" {
  command = plan
  assert {
    condition     = one(azurerm_network_security_group.server.security_rule).access == "Allow"
    error_message = "The default incident state must start healthy."
  }
}
run "injected_nsg_incident" {
  command = plan
  variables { incident = "nsg-block" }
  assert {
    condition     = one(azurerm_network_security_group.server.security_rule).access == "Deny"
    error_message = "The controlled incident must block server HTTP."
  }
}

run "incident_dns_wrong" {
  command = plan
  variables { incident = "dns-wrong" }
  assert {
    condition     = azurerm_private_dns_a_record.app.records == toset(["10.34.2.99"])
    error_message = "The selected dns-wrong incident must change only its intended layer."
  }
}

run "incident_route_drop" {
  command = plan
  variables { incident = "route-drop" }
  assert {
    condition     = length(azurerm_route.drop) == 1 && azurerm_route.drop[0].address_prefix == "10.34.2.4/32" && azurerm_route.drop[0].next_hop_type == "None"
    error_message = "The selected route-drop incident must change only its intended layer."
  }
}

run "incident_app_stopped" {
  command = plan
  variables { incident = "app-stopped" }
  assert {
    condition     = strcontains(module.server.bootstrap_command, "Stop-Service W3SVC -Force") && azurerm_private_dns_a_record.app.records == toset(["10.34.2.4"]) && length(azurerm_route.drop) == 0
    error_message = "The selected app-stopped incident must change only its intended layer."
  }
}
