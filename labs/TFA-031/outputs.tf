output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "vpn_connection_ids" {
  value = {
    for key, connection in azurerm_virtual_network_gateway_connection.tunnel : key => connection.id
  }
}

output "dns_vm_name" {
  value = module.dns.name
}

output "onprem_dns_server" {
  value = module.dns.private_ip_address
}

output "resolver_inbound_ip" {
  value = azurerm_private_dns_resolver_inbound_endpoint.lab.ip_configurations[0].private_ip_address
}

output "blob_hostname" {
  value = "${azurerm_storage_account.lab.name}.blob.core.windows.net"
}

output "blob_private_ip" {
  value = azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
}
