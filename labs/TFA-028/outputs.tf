output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "workspace_id" {
  value = azurerm_log_analytics_workspace.lab.workspace_id
}

output "ops_vm_name" {
  value = module.ops.name
}

output "audit_vault_name" { value = azurerm_key_vault.audit.name }
