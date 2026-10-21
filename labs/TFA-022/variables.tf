variable "subscription_id" {
  description = "Azure subscription to charge. Supply explicitly; never infer the active CLI subscription."
  type        = string
}

variable "location" {
  description = "Azure region. Check service availability and quota before apply."
  type        = string
  default     = "westeurope"
}

variable "name_prefix" {
  description = "Short, lowercase lab resource prefix."
  type        = string
  default     = "tfa022"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,11}$", var.name_prefix))
    error_message = "Use 3-12 lowercase letters, digits or hyphens, beginning with a letter."
  }
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default = {
  }
}
