variable "checks" {
  description = "Self-reported readiness evidence; run the README checks before setting these true."
  type        = object({ tools = bool, identity = bool, subscription = bool, providers = bool, quota = bool, budget = bool })
  default     = { tools = false, identity = false, subscription = false, providers = false, quota = false, budget = false }
}

locals {
  incomplete = [for name, passed in var.checks : name if !passed]
}

output "readiness" {
  description = "A local checklist; Terraform does not verify Azure permissions or quotas here."
  value       = { ready = length(local.incomplete) == 0, incomplete = local.incomplete }
}
