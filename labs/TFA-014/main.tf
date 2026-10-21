variable "revision" {
  description = "Change the revision to make a local update for the lock exercise."
  type        = number
  default     = 1
}

resource "terraform_data" "service" {
  for_each = toset(["api", "web"])
  input    = { name = each.key, revision = var.revision }
}

output "service_ids" {
  description = "Built-in resources have identities persisted in local state."
  value       = { for name, service in terraform_data.service : name => service.id }
}
