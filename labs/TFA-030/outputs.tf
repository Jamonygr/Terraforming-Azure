output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "vpn_connection_ids" {
  value = {
    for key, connection in azurerm_virtual_network_gateway_connection.tunnel : key => connection.id
  }
}

output "azure_vm_name" {
  value = module.azure.name
}

output "onprem_vm_name" {
  value = module.onprem.name
}

output "azure_private_ip" {
  value = module.azure.private_ip_address
}

output "onprem_private_ip" {
  value = module.onprem.private_ip_address
}
