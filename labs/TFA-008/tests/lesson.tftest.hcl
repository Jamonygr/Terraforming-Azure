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
  subscription_id      = "11111111-1111-1111-1111-111111111111"
  probe_admin_password = "OfflineFixtureOnly!2026"
}
run "default_is_configuration_only" {
  command = plan
  assert {
    condition     = length(module.probe) == 0 && length(azurerm_nat_gateway.probe) == 0 && length(azurerm_network_interface_application_security_group_association.web) == 0
    error_message = "The baseline must not create optional billed probes or imply ASG membership."
  }
}
run "asg_member_matches_before_deny" {
  command = plan
  variables { enable_probes = true }
  assert {
    condition     = length(module.probe) == 2 && one(azurerm_network_interface_application_security_group_association.web).network_interface_id == module.probe["server"].network_interface_id && azurerm_network_security_rule.https.priority < azurerm_network_security_rule.deny_vnet.priority
    error_message = "The optional server must belong to the allowed ASG before the deny rule."
  }
}
run "membership_fault_keeps_hosts" {
  command = plan
  variables {
    enable_probes          = true
    web_membership_enabled = false
  }
  assert {
    condition     = length(module.probe) == 2 && length(azurerm_network_interface_application_security_group_association.web) == 0 && azurerm_network_security_rule.deny_vnet.access == "Deny"
    error_message = "The fault must remove membership while retaining hosts and deny policy."
  }
}
