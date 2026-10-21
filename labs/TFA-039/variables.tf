variable "approved_address_spaces" {
  type = map(string)
  default = {
    hub = "10.0.0.0/16", app = "10.10.0.0/16", data = "10.20.0.0/16", operations = "10.30.0.0/16", onprem = "192.168.0.0/16"
  }

  validation {
    condition     = length(distinct(values(var.approved_address_spaces))) == length(var.approved_address_spaces)
    error_message = "Every network must use a distinct address block. Also manually check partial CIDR overlap."
  }
}

variable "cost_reviewed" {
  type    = bool
  default = false
}

variable "quota_reviewed" {
  type    = bool
  default = false
}

variable "cleanup_owner_confirmed" {
  type    = bool
  default = false
}
