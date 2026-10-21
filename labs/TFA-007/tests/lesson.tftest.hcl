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
  mock_resource "azurerm_application_security_group" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/applicationSecurityGroups/web" }
  }

}
variables {
  subscription_id = "11111111-1111-1111-1111-111111111111"
}
run "derived_subnets_are_distinct_and_contained" {
  command = plan
  assert {
    condition     = toset(flatten(values(output.address_plan))) == toset(["10.7.1.0/24", "10.7.2.0/24", "10.7.3.0/24"])
    error_message = "The /16 lesson must derive three distinct contained /24 subnets."
  }
}
run "reject_malformed_cidr" {
  command = plan
  variables { address_space = "not-a-cidr" }
  expect_failures = [var.address_space]
}
run "reject_wrong_allocation_size" {
  command = plan
  variables { address_space = "10.7.0.0/24" }
  expect_failures = [var.address_space]
}
run "reject_noncanonical_host_bits" {
  command = plan
  variables { address_space = "10.7.1.0/16" }
  expect_failures = [var.address_space]
}
