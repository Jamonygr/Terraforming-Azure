output "resource_group_name" {
  description = "Network lifecycle resource-group name."
  value       = azurerm_resource_group.network.name
}
output "vnet_id" {
  description = "VNet ARM resource ID for peering and composition."
  value       = azurerm_virtual_network.network.id
}
output "vnet_name" {
  description = "VNet name for operational commands."
  value       = azurerm_virtual_network.network.name
}
output "subnet_ids" {
  description = "Subnet ARM IDs indexed by the stable input keys."
  value       = { for name, subnet in azurerm_subnet.subnet : name => subnet.id }
}
