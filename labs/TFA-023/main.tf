locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-023", managed_by = "Terraform"
    }
  )
  suffix = substr(sha256("${var.subscription_id}:${var.name_prefix}:${var.location}"), 0, 8)
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
  address_space       = ["10.23.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "services" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.23.1.0/24"]
}

resource "azurerm_storage_account" "lab" {
  name                            = "st${replace(var.name_prefix, "-", "")}${local.suffix}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  tags                            = local.tags
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "blob-to-main"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${var.name_prefix}-blob"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.services.id
  private_service_connection {
    name                           = "blob"
    private_connection_resource_id = azurerm_storage_account.lab.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = local.tags
}

resource "azurerm_subnet" "probe" {
  name                 = "snet-probe"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.23.2.0/24"]
}
module "probe" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-probe"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.probe.id
  admin_password      = var.admin_password

  tags = local.tags
}
resource "azurerm_public_ip" "probe_nat" {
  name                = "pip-${var.name_prefix}-probe-nat"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}
resource "azurerm_nat_gateway" "probe" {
  name                = "nat-${var.name_prefix}-probe"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "Standard"
  tags                = local.tags
}
resource "azurerm_nat_gateway_public_ip_association" "probe" {
  nat_gateway_id       = azurerm_nat_gateway.probe.id
  public_ip_address_id = azurerm_public_ip.probe_nat.id
}
resource "azurerm_subnet_nat_gateway_association" "probe" {
  subnet_id      = azurerm_subnet.probe.id
  nat_gateway_id = azurerm_nat_gateway.probe.id
}
