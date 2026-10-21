terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.77.0"
    }
  }
}

provider "azurerm" {
  features {
    storage {
      # Bootstrap RBAC cannot exist before the account; use ARM-only creation.
      data_plane_available = false
    }
  }
  subscription_id                 = var.subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
}

variable "subscription_id" {
  type        = string
  description = "Explicit training subscription ID."
}
variable "location" {
  type    = string
  default = "westeurope"
}
variable "name_prefix" {
  type    = string
  default = "tfa"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,8}$", var.name_prefix))
    error_message = "Use 3–9 lowercase letters/digits so the state account stays within 24 characters."
  }
}
variable "backend_principal_id" {
  type        = string
  default     = null
  description = "Optional additional OIDC principal object ID. The current operator retains backend access."
}
data "azurerm_client_config" "current" {}
locals {
  suffix = substr(sha256("${var.subscription_id}:${var.name_prefix}"), 0, 10)
  tags   = { project = "Terraforming-Azure", purpose = "training-state" }
}
resource "azurerm_resource_group" "state" {
  name     = "${var.name_prefix}-state-rg"
  location = var.location
  tags     = local.tags
}
resource "azurerm_storage_account" "state" {
  name                            = "${var.name_prefix}state${local.suffix}"
  resource_group_name             = azurerm_resource_group.state.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }
  tags = local.tags
}
resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}
resource "azurerm_role_assignment" "operator" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
resource "azurerm_role_assignment" "oidc" {
  count                = var.backend_principal_id == null ? 0 : 1
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.backend_principal_id
}
output "storage_account_name" { value = azurerm_storage_account.state.name }
output "container_name" { value = azurerm_storage_container.state.name }
output "resource_group_name" { value = azurerm_resource_group.state.name }
output "tenant_id" { value = data.azurerm_client_config.current.tenant_id }
output "backend_key" { value = "bootstrap.terraform.tfstate" }
output "storage_account_id" { value = azurerm_storage_account.state.id }
