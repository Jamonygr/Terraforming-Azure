resource "azurerm_resource_group" "lab" {
  name     = "rg-${local.prefix}-capstone"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "network" {
  for_each            = local.networks
  name                = "vnet-${local.prefix}-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = var.location
  address_space       = [each.value]
  tags                = local.tags
}

resource "azurerm_subnet" "subnet" {
  for_each                          = local.subnets
  name                              = each.value.name
  resource_group_name               = azurerm_resource_group.lab.name
  virtual_network_name              = azurerm_virtual_network.network[each.value.network].name
  address_prefixes                  = [each.value.prefix]
  private_endpoint_network_policies = each.key == "data" ? "Enabled" : "Disabled"
  default_outbound_access_enabled   = false

  dynamic "delegation" {
    for_each = contains(["dns_in", "dns_out"], each.key) ? [1] : []
    content {
      name = "dns-resolver"
      service_delegation {
        name    = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each                     = toset(["app", "data", "operations"])
  name                         = "hub-to-${each.key}"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.network["hub"].name
  remote_virtual_network_id    = azurerm_virtual_network.network[each.key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = local.hybrid
  # Both gateways must exist before enabling transit.
  depends_on = [azurerm_virtual_network_gateway.vpn]
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each                     = toset(["app", "data", "operations"])
  name                         = "${each.key}-to-hub"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.network[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.network["hub"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = local.hybrid
  depends_on                   = [azurerm_virtual_network_peering.hub_to_spoke]
}

resource "azurerm_virtual_network_dns_servers" "spokes" {
  for_each           = local.secure ? toset(["app", "data", "operations"]) : toset([])
  virtual_network_id = azurerm_virtual_network.network[each.key].id
  dns_servers        = [azurerm_firewall.hub[0].ip_configuration[0].private_ip_address]
}

resource "azurerm_virtual_network_dns_servers" "onprem" {
  count              = local.hybrid ? 1 : 0
  virtual_network_id = azurerm_virtual_network.network["onprem"].id
  dns_servers        = [local.corp_dns_ip]
  # Bootstrap corp01 on Azure DNS first. Pointing DHCP to a not-yet-installed
  # DNS role would prevent the VM agent downloading its configuration handler.
  depends_on = [azurerm_virtual_machine_extension.corp_dns]
}

resource "azurerm_route_table" "workload" {
  for_each                      = local.secure ? toset(["app", "data", "operations"]) : toset([])
  name                          = "rt-${local.prefix}-${each.key}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.lab.name
  bgp_route_propagation_enabled = false
  tags                          = local.tags
}

resource "azurerm_route" "default" {
  for_each               = azurerm_route_table.workload
  name                   = "internet-via-firewall"
  resource_group_name    = azurerm_resource_group.lab.name
  route_table_name       = each.value.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
}

resource "azurerm_route" "private" {
  for_each = local.secure ? {
    for pair in setproduct(["app", "data", "operations"], ["app", "data", "operations", "onprem"]) :
    "${pair[0]}-${pair[1]}" => { source = pair[0], destination = pair[1] } if pair[0] != pair[1]
  } : {}
  name                   = "${each.value.destination}-via-firewall"
  resource_group_name    = azurerm_resource_group.lab.name
  route_table_name       = azurerm_route_table.workload[each.value.source].name
  address_prefix         = local.networks[each.value.destination]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "workload" {
  for_each       = azurerm_route_table.workload
  subnet_id      = azurerm_subnet.subnet[each.key].id
  route_table_id = each.value.id
  depends_on     = [azurerm_route.default, azurerm_route.private]
}

resource "azurerm_route_table" "gateway" {
  count                         = local.hybrid ? 1 : 0
  name                          = "rt-${local.prefix}-gateway"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.lab.name
  bgp_route_propagation_enabled = true
  tags                          = local.tags
}

resource "azurerm_route" "gateway_to_spokes" {
  for_each               = local.hybrid ? toset(["app", "data", "operations"]) : toset([])
  name                   = "${each.key}-via-firewall"
  resource_group_name    = azurerm_resource_group.lab.name
  route_table_name       = azurerm_route_table.gateway[0].name
  address_prefix         = local.networks[each.key]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "gateway" {
  count          = local.hybrid ? 1 : 0
  subnet_id      = azurerm_subnet.subnet["gateway"].id
  route_table_id = azurerm_route_table.gateway[0].id
  depends_on     = [azurerm_route.gateway_to_spokes]
}
