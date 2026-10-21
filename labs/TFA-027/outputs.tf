output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "gateway_public_ip" {
  value = azurerm_public_ip.gateway.ip_address
}

output "request_host" {
  value = "app.terraforming-azure.test"
}

output "gateway_name" {
  value = azurerm_application_gateway.lab.name
}
