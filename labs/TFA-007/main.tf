resource "azurerm_resource_group" "lab" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

output "resource_group_name" {
  description = "Resource group owned by this independent lab."
  value       = azurerm_resource_group.lab.name
}

variable "address_space" {
  description = "A private IPv4 /16 for the independent network."
  type        = string
  default     = "10.7.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.address_space))
    error_message = "Supply a valid IPv4 CIDR."
  }
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "tier" {
  for_each                        = { web = 1, app = 2, data = 3 }
  name                            = each.key
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = [cidrsubnet(var.address_space, 8, each.value)]
  default_outbound_access_enabled = false
}

output "address_plan" {
  description = "Derived subnet prefixes and stable subnet keys."
  value       = { for key, subnet in azurerm_subnet.tier : key => subnet.address_prefixes }
}

output "vnet_name" {
  description = "Name for Azure CLI address-plan inspection."
  value       = azurerm_virtual_network.lab.name
}
