resource "azurerm_resource_group" "lab" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

output "resource_group_name" {
  description = "Resource group owned by this independent lab."
  value       = azurerm_resource_group.lab.name
}

locals {
  networks = { hub = "10.12.0.0/16", spoke = "10.13.0.0/16", isolated = "10.14.0.0/16" }
  peers    = { hub_to_spoke = { from = "hub", to = "spoke" }, spoke_to_hub = { from = "spoke", to = "hub" } }
}

resource "azurerm_virtual_network" "network" {
  for_each            = local.networks
  name                = "${var.name_prefix}-${each.key}-vnet"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = [each.value]
  tags                = local.tags
}

resource "azurerm_virtual_network_peering" "peer" {
  for_each                     = local.peers
  name                         = each.key
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.network[each.value.from].name
  remote_virtual_network_id    = azurerm_virtual_network.network[each.value.to].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

output "vnet_names" {
  description = "Hub/spoke have a direct pair; isolated has no peering."
  value       = { for key, net in azurerm_virtual_network.network : key => net.name }
}
