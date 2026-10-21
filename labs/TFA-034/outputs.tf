output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "client_vm_name" {
  value = module.client.name
}

output "server_vm_name" {
  value = module.server.name
}

output "server_nic_id" {
  value = module.server.network_interface_id
}

output "server_private_ip" {
  value = module.server.private_ip_address
}

output "incident" {
  value = var.incident
}
