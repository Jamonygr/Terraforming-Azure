resource "azurerm_storage_account" "data" {
  count                           = local.apps ? 1 : 0
  name                            = "st${var.name_prefix}${local.suffix}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  https_traffic_only_enabled      = true
  tags                            = local.tags
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "data" {
  count                         = local.apps ? 1 : 0
  name                          = "kv-${var.name_prefix}-${local.suffix}"
  resource_group_name           = azurerm_resource_group.lab.name
  location                      = var.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  tags                          = local.tags
}

resource "azurerm_private_endpoint" "data" {
  for_each            = local.apps ? toset(["blob", "vault"]) : toset([])
  name                = "pe-${local.prefix}-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = var.location
  subnet_id           = azurerm_subnet.subnet["data"].id
  private_service_connection {
    name                           = "psc-${each.key}"
    private_connection_resource_id = each.key == "blob" ? azurerm_storage_account.data[0].id : azurerm_key_vault.data[0].id
    subresource_names              = [each.key == "blob" ? "blob" : "vault"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zone[each.key].id]
  }
  tags = local.tags
}

# ARM role assignments only. The private seed script creates the container/blob and
# sample secret from ops01; public CI/local Terraform never needs private data-plane access.
resource "azurerm_role_assignment" "blob" {
  for_each             = { for key, value in local.vms : key => value }
  scope                = azurerm_storage_account.data[0].id
  role_definition_name = each.key == "ops01" ? "Storage Blob Data Contributor" : "Storage Blob Data Reader"
  principal_id         = azurerm_windows_virtual_machine.vm[each.key].identity[0].principal_id
}

resource "azurerm_role_assignment" "vault" {
  for_each             = { for key, value in local.vms : key => value }
  scope                = azurerm_key_vault.data[0].id
  role_definition_name = each.key == "ops01" ? "Key Vault Secrets Officer" : "Key Vault Secrets User"
  principal_id         = azurerm_windows_virtual_machine.vm[each.key].identity[0].principal_id
}
