locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-026", managed_by = "Terraform"
    }
  )
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.26.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.26.0.0/26"]
}

resource "azurerm_virtual_network" "spoke_a" {
  name                = "vnet-${var.name_prefix}-spoke_a"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.126.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "app_a" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.spoke_a.name
  address_prefixes     = ["10.126.1.0/24"]
}

resource "azurerm_virtual_network" "spoke_b" {
  name                = "vnet-${var.name_prefix}-spoke_b"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.226.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "app_b" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.spoke_b.name
  address_prefixes     = ["10.226.1.0/24"]
}

resource "azurerm_virtual_network_peering" "hub_to_spoke_a" {
  name                         = "hub-to-spoke_a"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_a.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_a_to_hub" {
  name                         = "spoke_a-to-hub"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.spoke_a.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke_b" {
  name                         = "hub-to-spoke_b"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_b.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_b_to_hub" {
  name                         = "spoke_b-to-hub"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.spoke_b.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.name_prefix}-firewall"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_firewall_policy" "lab" {
  name                     = "afwp-${var.name_prefix}"
  location                 = azurerm_resource_group.lab.location
  resource_group_name      = azurerm_resource_group.lab.name
  sku                      = "Standard"
  threat_intelligence_mode = "Alert"
  tags                     = local.tags
}

resource "azurerm_firewall" "lab" {
  name                = "afw-${var.name_prefix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.lab.id
  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = local.tags
}

module "client" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-client"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.app_a.id
  admin_password      = var.admin_password
  bootstrap_command   = ""

  tags = local.tags
}

module "server" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-server"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.app_b.id
  admin_password      = var.admin_password
  bootstrap_command   = ""

  tags = local.tags
}

resource "azurerm_route_table" "spokes" {
  for_each = {
    a = "10.226.0.0/16", b = "10.126.0.0/16"
  }

  name                = "rt-${var.name_prefix}-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  route {
    name                   = "other-spoke-via-firewall"
    address_prefix         = each.value
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.lab.ip_configuration[0].private_ip_address
  }

  tags = local.tags
}

resource "azurerm_subnet_route_table_association" "spokes" {
  for_each = {
    a = azurerm_subnet.app_a.id, b = azurerm_subnet.app_b.id
  }

  subnet_id      = each.value
  route_table_id = azurerm_route_table.spokes[each.key].id
}

resource "azurerm_firewall_policy_rule_collection_group" "east_west" {
  name               = "east-west"
  firewall_policy_id = azurerm_firewall_policy.lab.id
  priority           = 200
  network_rule_collection {
    name     = "allow-icmp-test"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "client-to-server-icmp"
      protocols             = ["ICMP"]
      source_addresses      = ["10.126.1.0/24"]
      destination_addresses = ["10.226.1.0/24"]
      destination_ports     = ["*"]
    }
  }
}
