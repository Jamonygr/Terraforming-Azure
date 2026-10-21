# Synthetic schema-valid IDs only. No Azure authentication or API calls occur.
mock_data "azurerm_client_config" {
  defaults = { tenant_id = "11111111-1111-1111-1111-111111111111", subscription_id = "22222222-2222-2222-2222-222222222222" }
}
mock_data "azurerm_monitor_diagnostic_categories" {
  defaults = { log_category_types = ["SyntheticLog"], metrics = ["AllMetrics"] }
}
mock_resource "azurerm_resource_group" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg"
  }
}
mock_resource "azurerm_virtual_network" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock"
  }
}
mock_resource "azurerm_subnet" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock/subnets/mock"
  }
}
mock_resource "azurerm_public_ip" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/publicIPAddresses/mock"
  }
}
mock_resource "azurerm_firewall_policy" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/firewallPolicies/mock"
  }
}
mock_resource "azurerm_firewall" {
  defaults = {
    id               = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/azureFirewalls/mock"
    ip_configuration = { private_ip_address = "10.0.0.4" }
  }
}
mock_resource "azurerm_network_security_group" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/networkSecurityGroups/mock"
  }
}
mock_resource "azurerm_private_dns_zone" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/mock.test"
  }
}
mock_resource "azurerm_private_dns_resolver" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/dnsResolvers/mock"
  }
}
mock_resource "azurerm_private_dns_resolver_inbound_endpoint" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/dnsResolvers/mock/inboundEndpoints/mock"
  }
}
mock_resource "azurerm_private_dns_resolver_outbound_endpoint" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/dnsResolvers/mock/outboundEndpoints/mock"
  }
}
mock_resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/dnsForwardingRulesets/mock"
  }
}
mock_resource "azurerm_virtual_network_gateway" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworkGateways/mock"
  }
}
mock_resource "azurerm_network_interface" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/networkInterfaces/mock"
  }
}
mock_resource "azurerm_windows_virtual_machine" {
  defaults = {
    id       = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Compute/virtualMachines/mock"
    identity = { principal_id = "33333333-3333-3333-3333-333333333333", tenant_id = "11111111-1111-1111-1111-111111111111" }
  }
}
mock_resource "azurerm_storage_account" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockstorage"
  }
}
mock_resource "azurerm_key_vault" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.KeyVault/vaults/mock"
  }
}
mock_resource "azurerm_application_gateway" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/applicationGateways/mock"
  }
}
mock_resource "azurerm_web_application_firewall_policy" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies/mock"
  }
}
mock_resource "azurerm_log_analytics_workspace" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.OperationalInsights/workspaces/mock"
  }
}
mock_resource "azurerm_monitor_action_group" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Insights/actionGroups/mock"
  }
}
mock_resource "azurerm_monitor_data_collection_rule" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Insights/dataCollectionRules/mock"
  }
}
mock_resource "azurerm_monitor_data_collection_endpoint" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Insights/dataCollectionEndpoints/mock"
  }
}
mock_resource "azurerm_route_table" {
  defaults = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/routeTables/mock"
  }
}
mock_resource "azurerm_bastion_host" { defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/bastionHosts/mock" } }
mock_resource "azurerm_nat_gateway" { defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/natGateways/mock" } }
