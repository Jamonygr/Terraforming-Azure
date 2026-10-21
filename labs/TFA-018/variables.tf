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
  default     = "tfa018"
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
    lab     = "TFA-018"
    purpose = "learning"
  })
}

variable "subnets" {
  description = "Stable subnet keys are resource identities: adding is different from renaming."
  type        = map(string)
  default     = { web = "10.18.1.0/24", app = "10.18.2.0/24" }
  validation {
    condition     = length(var.subnets) > 0 && alltrue([for prefix in values(var.subnets) : can(cidrnetmask(prefix))])
    error_message = "Supply at least one subnet with a valid IPv4 CIDR."
  }
}
