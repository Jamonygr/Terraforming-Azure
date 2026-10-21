output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "storage_account_name" {
  value = azurerm_storage_account.lab.name
}

output "blob_hostname" {
  value = "${azurerm_storage_account.lab.name}.blob.core.windows.net"
}

output "private_endpoint_ip" {
  value = azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
}

output "probe_vm_name" { value = module.probe.name }
