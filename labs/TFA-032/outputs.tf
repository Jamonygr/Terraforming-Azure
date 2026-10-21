output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "policy_assignment_id" {
  value = azurerm_resource_group_policy_assignment.tag.id
}

output "budget_id" {
  value = azurerm_consumption_budget_resource_group.lab.id
}
