variable "operation" {
  type    = string
  default = "plan"
  validation {
    condition     = contains(["plan", "apply", "destroy"], var.operation)
    error_message = "Use plan, apply or destroy."
  }
}
