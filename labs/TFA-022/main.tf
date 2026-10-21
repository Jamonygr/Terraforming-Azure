locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-022", managed_by = "Terraform"
    }
  )
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.name_prefix}-main"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.22.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "services" {
  name                 = "snet-services"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.22.1.0/24"]
}

resource "azurerm_dns_zone" "public" {
  name                = "${var.name_prefix}.example.com"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_dns_a_record" "public" {
  name                = "demo"
  zone_name           = azurerm_dns_zone.public.name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 300
  records             = ["192.0.2.10"]
  tags                = local.tags
}

resource "azurerm_private_dns_zone" "internal" {
  name                = "internal.terraforming-azure.test"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = "internal-to-main"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_a_record" "app" {
  name                = "app"
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 60
  records             = ["10.22.1.10"]
  tags                = local.tags
}
