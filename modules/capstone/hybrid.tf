resource "azurerm_public_ip" "vpn" {
  for_each            = local.hybrid ? toset(["hub", "onprem"]) : toset([])
  name                = "pip-${local.prefix}-vpn-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway" "vpn" {
  for_each            = local.hybrid ? toset(["hub", "onprem"]) : toset([])
  name                = "vgw-${local.prefix}-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1AZ"
  generation          = "Generation1"
  active_active       = false
  bgp_enabled         = false
  ip_configuration {
    name                          = "primary"
    public_ip_address_id          = azurerm_public_ip.vpn[each.key].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnet[each.key == "hub" ? "gateway" : "remote_gw"].id
  }
  tags = local.tags
}

resource "azurerm_virtual_network_gateway_connection" "vpn" {
  for_each                        = local.hybrid ? { hub = "onprem", onprem = "hub" } : {}
  name                            = "vpn-${each.key}-to-${each.value}"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.lab.name
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.vpn[each.key].id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn[each.value].id
  shared_key                      = var.vpn_shared_key
  bgp_enabled                     = false
  tags                            = local.tags
}

# Simulation plumbing: private Azure-hosted corp01 still needs explicit public
# egress for VM extensions and Azure Monitor. Private Azure destinations use VPN.
resource "azurerm_public_ip" "onprem_nat" {
  count               = local.hybrid ? 1 : 0
  name                = "pip-${local.prefix}-onprem-nat"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "onprem" {
  count               = local.hybrid ? 1 : 0
  name                = "nat-${local.prefix}-onprem"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "onprem" {
  count                = local.hybrid ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.onprem[0].id
  public_ip_address_id = azurerm_public_ip.onprem_nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "onprem" {
  count          = local.hybrid ? 1 : 0
  subnet_id      = azurerm_subnet.subnet["corp"].id
  nat_gateway_id = azurerm_nat_gateway.onprem[0].id
  depends_on     = [azurerm_nat_gateway_public_ip_association.onprem]
}
