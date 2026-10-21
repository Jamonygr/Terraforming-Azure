variable "location" {
  description = "Azure region for this lesson. Check service and SKU availability before deployment."
  type        = string
  default     = "westeurope"
}

variable "name_prefix" {
  description = "Short lowercase prefix used to isolate this lesson's resources."
  type        = string
  default     = "tfa001"
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
    lab     = "TFA-001"
    purpose = "learning"
  })
}
