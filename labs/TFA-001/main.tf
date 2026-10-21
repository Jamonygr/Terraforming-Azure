locals {
  azure_model = {
    tenant         = "identity boundary"
    subscription   = "billing and access boundary"
    resource_group = "lifecycle boundary"
    resource       = "one managed Azure object"
    region         = var.location
  }
}

resource "terraform_data" "intent" {
  input = { model = local.azure_model, resource_group_name = "${var.name_prefix}-rg", tags = local.tags }
}

output "desired_infrastructure" {
  description = "A local model only; no Azure account or provider is used."
  value       = terraform_data.intent.output
}
