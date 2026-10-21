locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-024", managed_by = "Terraform"
    }
  )
  suffix = substr(sha256("${var.subscription_id}:${var.name_prefix}:${var.location}"), 0, 8)
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

data "azurerm_client_config" "current" {
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.name_prefix}-app"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_key_vault" "lab" {
  name                       = "kv-${var.name_prefix}-${local.suffix}"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}

resource "azurerm_role_assignment" "read_secrets" {
  count = var.identity_secret_role == "None" ? 0 : 1

  scope                = azurerm_key_vault.lab.id
  role_definition_name = var.identity_secret_role
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_virtual_network" "probe" {
  name                = "vnet-${var.name_prefix}-probe"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.24.0.0/16"]
  tags                = local.tags
}
resource "azurerm_subnet" "probe" {
  name                 = "snet-probe"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.probe.name
  address_prefixes     = ["10.24.1.0/24"]
}
module "probe" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-probe"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.probe.id
  admin_password      = var.admin_password
  identity_ids        = [azurerm_user_assigned_identity.app.id]
  tags                = local.tags
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
