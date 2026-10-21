output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "firewall_private_ip" {
  value = azurerm_firewall.lab.ip_configuration[0].private_ip_address
}

output "policy_id" {
  value = azurerm_firewall_policy.lab.id
}

output "probe_vm_name" { value = module.probe.name }
output "workspace_id" { value = azurerm_log_analytics_workspace.firewall.workspace_id }
