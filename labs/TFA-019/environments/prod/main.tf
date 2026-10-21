terraform {
  required_version = ">= 1.9, < 2.0"
}

variable "revision" {
  description = "Only the current environment observes this input."
  type        = number
  default     = 1
}

resource "terraform_data" "environment" {
  input = { environment = "prod", address_space = "10.119.0.0/16", revision = var.revision }
}

output "environment" {
  description = "Recorded intent in this environment's separate state."
  value       = terraform_data.environment.output
}
