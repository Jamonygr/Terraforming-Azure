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

data "azurerm_resource_group" "observed" {
  name = azurerm_resource_group.lab.name
}

locals {
  workload_name = "${var.name_prefix}-web"
}

output "context" {
  description = "Control-plane identity and an observed group; object IDs are identifiers, not credentials."
  value = {
    tenant_id       = data.azurerm_client_config.current.tenant_id
    subscription_id = data.azurerm_client_config.current.subscription_id
    resource_group  = data.azurerm_resource_group.observed.name
    workload_name   = local.workload_name
  }
}
