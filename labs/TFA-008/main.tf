resource "azurerm_resource_group" "lab" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

output "resource_group_name" {
  description = "Resource group owned by this independent lab."
  value       = azurerm_resource_group.lab.name
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.8.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "workload" {
  name                            = "workload"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = ["10.8.1.0/24"]
  default_outbound_access_enabled = false
}

output "vnet_name" {
  description = "VNet name for CLI inspection."
  value       = azurerm_virtual_network.lab.name
}

output "subnet_id" {
  description = "Workload subnet resource ID."
  value       = azurerm_subnet.workload.id
}


resource "azurerm_application_security_group" "web" {
  name                = "${var.name_prefix}-web-asg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_network_security_group" "workload" {
  name                = "${var.name_prefix}-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "https" {
  name                                       = "allow-vnet-https-to-web"
  priority                                   = 100
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "443"
  source_address_prefix                      = "VirtualNetwork"
  destination_application_security_group_ids = [azurerm_application_security_group.web.id]
  resource_group_name                        = azurerm_resource_group.lab.name
  network_security_group_name                = azurerm_network_security_group.workload.name
}

resource "azurerm_network_security_rule" "deny_vnet" {
  name                        = "deny-other-vnet-inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

output "nsg_name" {
  description = "Subnet NSG for priority and default-rule inspection."
  value       = azurerm_network_security_group.workload.name
}
