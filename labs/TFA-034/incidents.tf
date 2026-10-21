resource "azurerm_private_dns_zone" "app" {
  name                = "tfa034.internal"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "app" {
  name                  = "clients"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.app.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}
resource "azurerm_private_dns_a_record" "app" {
  name                = "web"
  zone_name           = azurerm_private_dns_zone.app.name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 30
  records             = [var.incident == "dns-wrong" ? "10.34.2.99" : "10.34.2.4"]
}
resource "azurerm_route_table" "client" {
  name                = "rt-${var.name_prefix}-client"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
}
resource "azurerm_route" "drop" {
  count               = var.incident == "route-drop" ? 1 : 0
  name                = "discard-web"
  resource_group_name = azurerm_resource_group.lab.name
  route_table_name    = azurerm_route_table.client.name
  address_prefix      = "10.34.2.4/32"
  next_hop_type       = "None"
}
resource "azurerm_subnet_route_table_association" "client" {
  subnet_id      = azurerm_subnet.client.id
  route_table_id = azurerm_route_table.client.id
}
output "application_hostname" { value = "web.${azurerm_private_dns_zone.app.name}" }
output "client_nic_id" { value = module.client.network_interface_id }
