locals { egress_subnets = { azure = azurerm_subnet.azure_workload.id, onprem = azurerm_subnet.onprem_workload.id } }
resource "azurerm_public_ip" "probe_nat" {
  for_each            = toset(keys(local.egress_subnets))
  name                = "pip-${var.name_prefix}-${each.key}-egress"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}
resource "azurerm_nat_gateway" "probe" {
  for_each            = toset(keys(local.egress_subnets))
  name                = "nat-${var.name_prefix}-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "Standard"
  tags                = local.tags
}
resource "azurerm_nat_gateway_public_ip_association" "probe" {
  for_each             = toset(keys(local.egress_subnets))
  nat_gateway_id       = azurerm_nat_gateway.probe[each.key].id
  public_ip_address_id = azurerm_public_ip.probe_nat[each.key].id
}
resource "azurerm_subnet_nat_gateway_association" "probe" {
  for_each       = local.egress_subnets
  subnet_id      = each.value
  nat_gateway_id = azurerm_nat_gateway.probe[each.key].id
}
