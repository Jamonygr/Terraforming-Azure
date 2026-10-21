variable "environment" {
  description = "Choose the lifecycle and budget boundary."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test, or prod."
  }
}

variable "instance_count" {
  description = "Integer capacity, evaluated locally; no VMs are created."
  type        = number
  default     = 1
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 3 && floor(var.instance_count) == var.instance_count
    error_message = "Choose a whole number from 1 to 3."
  }
}

variable "workload" {
  description = "A typed object makes the configuration contract visible."
  type        = object({ name = string, enabled = bool, ports = set(number) })
  default     = { name = "web", enabled = true, ports = [443] }
}

output "configuration_preview" {
  description = "Typed and validated local configuration."
  value       = { name = "${var.name_prefix}-${var.environment}", location = var.location, tags = local.tags, replicas = var.instance_count, workload = var.workload }
}
