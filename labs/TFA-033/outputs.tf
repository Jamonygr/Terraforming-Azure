output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "subscription_boundaries" {
  value = {
    primary = azurerm_resource_group.lab.id, secondary = azurerm_resource_group.secondary.id
  }
}
