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
  default     = "tfa036"
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

variable "github_owner" {
  description = "Exact GitHub organization or account name."
  type        = string
}

variable "github_repository" {
  description = "Exact repository name, without owner."
  type        = string
}

variable "github_environment" {
  description = "Exact GitHub protected environment name used by the deployment workflow."
  type        = string
  default     = "azure-course"
}

variable "github_plan_environment" {
  description = "Exact protected GitHub environment used by plan-only jobs."
  type        = string
  default     = "azure-plan"
}
