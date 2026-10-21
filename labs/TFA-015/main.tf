resource "azurerm_resource_group" "current" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

moved {
  from = azurerm_resource_group.legacy
  to   = azurerm_resource_group.current
}

output "resource_group_name" {
  description = "Resource group whose tags are used for the controlled drift exercise."
  value       = azurerm_resource_group.current.name
}
