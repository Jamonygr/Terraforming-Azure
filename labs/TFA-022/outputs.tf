output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "authoritative_name_servers" {
  value = azurerm_dns_zone.public.name_servers
}

output "private_record" {
  value = azurerm_private_dns_a_record.app.fqdn
}
