locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-030", managed_by = "Terraform"
    }
  )
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "azure" {
  name                = "vnet-${var.name_prefix}-azure"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.30.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "azure_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.30.0.0/27"]
}

resource "azurerm_subnet" "azure_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.30.2.0/24"]
}

resource "azurerm_virtual_network" "onprem" {
  name                = "vnet-${var.name_prefix}-onprem"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.130.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "onprem_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.130.0.0/27"]
}

resource "azurerm_subnet" "onprem_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.130.2.0/24"]
}

resource "azurerm_public_ip" "gateway" {
  for_each            = toset(["azure", "onprem"])
  name                = "pip-${var.name_prefix}-${each.key}-vpn"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway" "lab" {
  for_each = {
    azure = azurerm_subnet.azure_gateway.id, onprem = azurerm_subnet.onprem_gateway.id
  }

  name                = "vpngw-${var.name_prefix}-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  bgp_enabled         = false
  sku                 = "VpnGw1AZ"
  ip_configuration {
    name                          = "primary"
    public_ip_address_id          = azurerm_public_ip.gateway[each.key].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = each.value
  }

  tags = local.tags
}

resource "azurerm_virtual_network_gateway_connection" "tunnel" {
  for_each = {
    azure = "onprem", onprem = "azure"
  }

  name                            = "vpn-${var.name_prefix}-${each.key}-to-${each.value}"
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.lab[each.key].id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.lab[each.value].id
  shared_key                      = var.vpn_shared_key
  tags                            = local.tags
}

module "azure" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-azure"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.azure_workload.id
  admin_password      = var.admin_password
  bootstrap_command   = ""

  tags = local.tags
}

module "onprem" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-onprem"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.onprem_workload.id
  admin_password      = var.admin_password
  bootstrap_command   = ""

  tags = local.tags
}
