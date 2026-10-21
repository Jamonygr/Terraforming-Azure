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
  default     = "tfa032"
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

variable "reader_principal_id" {
  description = "Object ID of an existing user/group/service principal to receive Reader only on this resource group."
  type        = string
}

variable "notification_email" {
  description = "Budget alert email address you control. Creating the budget enables Azure notifications."
  type        = string
}

variable "monthly_budget" {
  type    = number
  default = 25
}

variable "budget_start_date" {
  description = "First day of the current month, RFC3339 UTC, e.g. 2026-10-01T00:00:00Z. Set explicitly at execution time."
  type        = string
}

variable "enable_delete_lock" {
  type    = bool
  default = false
}
