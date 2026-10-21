variable "subscription_id" {
  description = "Explicit Azure subscription GUID. Never choose a subscription by display name."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "Supply the Azure subscription GUID."
  }
}

variable "location" {
  description = "Azure region for this lesson. Check service and SKU availability before deployment."
  type        = string
  default     = "westeurope"
}

variable "name_prefix" {
  description = "Short lowercase prefix used to isolate this lesson's resources."
  type        = string
  default     = "tfa011"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,11}$", var.name_prefix))
    error_message = "Use 3 to 12 lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "tags" {
  description = "Additional non-secret tags. Lab ownership tags remain explicit."
  type        = map(string)
  default     = {}
}

locals {
  tags = merge(var.tags, {
    project = "Terraforming-Azure"
    lab     = "TFA-011"
    purpose = "learning"
  })
}

variable "admin_password" {
  description = "Set TF_VAR_admin_password in the current PowerShell process; never put it in Git."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.admin_password) >= 16 && length(var.admin_password) <= 123
    error_message = "Use a unique Windows password between 16 and 123 characters meeting Azure complexity rules."
  }
}

variable "vm_size" {
  description = "A Windows VM SKU with quota in the chosen region; override if unavailable."
  type        = string
  default     = "Standard_B2s"
}
