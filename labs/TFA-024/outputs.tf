output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "identity_client_id" {
  value = azurerm_user_assigned_identity.app.client_id
}

output "vault_uri" {
  value = azurerm_key_vault.lab.vault_uri
}

output "probe_vm_name" { value = module.probe.name }
