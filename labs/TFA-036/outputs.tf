output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "AZURE_CLIENT_ID" {
  value = azurerm_user_assigned_identity.github.client_id
}

output "AZURE_TENANT_ID" {
  value = data.azurerm_client_config.current.tenant_id
}

output "AZURE_SUBSCRIPTION_ID" {
  value = var.subscription_id
}

output "identity_principal_id" {
  value = azurerm_user_assigned_identity.github.principal_id
}

output "federated_subject" {
  value = { for key, credential in azurerm_federated_identity_credential.github : key => credential.subject }
}

output "identity_name" {
  value = azurerm_user_assigned_identity.github.name
}
