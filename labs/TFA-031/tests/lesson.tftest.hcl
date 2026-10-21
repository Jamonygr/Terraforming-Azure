mock_provider "azurerm" {
  mock_resource "azurerm_private_dns_resolver_outbound_endpoint" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/dnsResolvers/mock/outboundEndpoints/outbound" }
  }
  mock_resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/dnsForwardingRulesets/mock" }
  }
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
override_resource {
  target          = azurerm_subnet.azure_gateway
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/azure_gateway/subnets/GatewaySubnet" }
}
override_resource {
  target          = azurerm_subnet.onprem_gateway
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/onprem_gateway/subnets/GatewaySubnet" }
}
variables {
  subscription_id = "11111111-1111-1111-1111-111111111111"
  admin_password  = "OfflineMockOnly!2026"
  vpn_shared_key  = "Offline-mock-tunnel-key-only-2026"
}
run "architecture_contract" {
  command = plan
  assert {
    condition     = azurerm_private_dns_resolver_inbound_endpoint.lab.ip_configurations[0].private_ip_address == "10.31.1.4"
    error_message = "The forwarder and resolver inbound address must match."
  }
  assert {
    condition     = azurerm_storage_account.lab.public_network_access_enabled == false
    error_message = "The hybrid query must resolve a genuinely private-only account."
  }
}

run "bidirectional_dns_contract" {
  command = plan
  assert {
    condition     = azurerm_private_dns_resolver_forwarding_rule.corp.domain_name == "corp.tfa.internal." && one(azurerm_private_dns_resolver_forwarding_rule.corp.target_dns_servers).ip_address == "10.131.2.4"
    error_message = "Corporate queries must forward to Windows DNS across VPN, not back into the Azure inbound endpoint."
  }
  assert {
    condition     = azurerm_private_dns_resolver_virtual_network_link.azure.virtual_network_id == azurerm_virtual_network.azure.id && azurerm_subnet.resolver_outbound.address_prefixes == tolist(["10.31.1.16/28"])
    error_message = "Azure clients require a ruleset link and a dedicated outbound subnet."
  }
  assert {
    condition     = anytrue([for rule in azurerm_network_security_group.dns.security_rule : rule.source_address_prefix == "10.31.1.16/28" && rule.destination_port_range == "53" && rule.access == "Allow"])
    error_message = "Corporate DNS must permit both UDP/TCP resolver queries."
  }
}
