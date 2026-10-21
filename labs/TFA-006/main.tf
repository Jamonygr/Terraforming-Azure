variable "workloads" {
  description = "Stable workload keys become for_each addresses."
  type        = map(string)
  default     = { api = "API service", web = "Web service" }
}

resource "azurerm_resource_group" "indexed" {
  count    = 2
  name     = "${var.name_prefix}-indexed-${count.index}-rg"
  location = var.location
  tags     = merge(local.tags, { identity_model = "count" })
}

resource "azurerm_resource_group" "keyed" {
  for_each = var.workloads
  name     = "${var.name_prefix}-${each.key}-rg"
  location = var.location
  tags     = merge(local.tags, { description = each.value, identity_model = "for_each" })
}

output "addresses" {
  description = "Index and key identities can be compared with terraform state list."
  value       = { indexed = azurerm_resource_group.indexed[*].name, keyed = { for key, group in azurerm_resource_group.keyed : key => group.name } }
}
