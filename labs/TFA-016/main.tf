resource "azurerm_resource_group" "lab" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

output "resource_group_name" {
  description = "Resource group owned by this independent lab."
  value       = azurerm_resource_group.lab.name
}

data "azurerm_client_config" "current" {}

resource "azurerm_storage_account" "state" {
  name                            = "${replace(var.name_prefix, "-", "")}${substr(sha256(var.subscription_id), 0, 8)}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  tags                            = local.tags
  blob_properties {
    versioning_enabled = true
    delete_retention_policy { days = 7 }
    container_delete_retention_policy { days = 7 }
  }
}

resource "azurerm_role_assignment" "blob_data" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
  depends_on            = [azurerm_role_assignment.blob_data]
}

output "backend_configuration" {
  description = "Non-secret backend settings; Azure Entra authentication is required."
  value = {
    resource_group_name  = azurerm_resource_group.lab.name
    storage_account_name = azurerm_storage_account.state.name
    container_name       = azurerm_storage_container.state.name
    key                  = "tfa016.terraform.tfstate"
    tenant_id            = data.azurerm_client_config.current.tenant_id
    subscription_id      = var.subscription_id
    use_azuread_auth     = true
    use_cli              = true
  }
}
