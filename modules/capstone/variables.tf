variable "location" {
  type    = string
  default = "westeurope"
}

variable "name_prefix" {
  type    = string
  default = "tfazure"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.name_prefix))
    error_message = "Use 3-12 lowercase letters/numbers, starting with a letter."
  }
}

variable "environment" {
  type    = string
  default = "lab"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,5}$", var.environment))
    error_message = "Use 2-6 lowercase letters/numbers, starting with a letter."
  }
}

variable "stage" {
  type    = string
  default = "foundation"
  validation {
    condition     = contains(["foundation", "secure", "applications", "hybrid"], var.stage)
    error_message = "stage must be foundation, secure, applications, or hybrid."
  }
}

variable "address_plan" {
  description = "Non-overlapping /16 VNets. Subnet addresses are derived inside each range."
  type = object({
    hub        = string
    app        = string
    data       = string
    operations = string
    onprem     = string
  })
  default = {
    hub        = "10.0.0.0/16", app = "10.10.0.0/16", data = "10.20.0.0/16"
    operations = "10.30.0.0/16", onprem = "192.168.0.0/16"
  }
  validation {
    condition = alltrue([
      for prefix in values(var.address_plan) : can(cidrhost(prefix, 4)) && can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/16$", prefix))
    ]) && length(distinct([for prefix in values(var.address_plan) : cidrhost(prefix, 0)])) == 5
    error_message = "Provide five distinct, valid IPv4 /16 address spaces."
  }
}

variable "operator_cidrs" {
  description = "Public IPv4 CIDRs allowed to the public WAF listener and Bastion. Use your public address /32."
  type        = list(string)
  validation {
    condition = length(var.operator_cidrs) > 0 && alltrue([
      for prefix in var.operator_cidrs : try(cidrhost(prefix, 0) == split("/", prefix)[0] && tostring(tonumber(split("/", prefix)[1])) == split("/", prefix)[1] && tonumber(split("/", prefix)[1]) >= 1 && tonumber(split("/", prefix)[1]) <= 32 && can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", prefix)), false)
    ])
    error_message = "Provide canonical IPv4 operator networks with prefixes /1 through /32; use your public /32. All /0 forms and host bits are rejected."
  }
}

variable "admin_password" {
  description = "Lab Windows local administrator password. Stored in protected Terraform state; never commit it."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.admin_password) >= 16 && length(var.admin_password) <= 123
    error_message = "Use a Windows-compliant password of 16-123 characters including upper/lowercase, number, and symbol."
  }
}

variable "certificate_path" {
  description = "Absolute path to ignored PFX for app.terraforming-azure.test; required at applications/hybrid."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "certificate_password" {
  type      = string
  default   = null
  nullable  = true
  sensitive = true
}

variable "vpn_shared_key" {
  description = "Same secret for the reciprocal IPsec connections. Required only for hybrid."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
  validation {
    condition     = var.stage != "hybrid" || try(length(var.vpn_shared_key) >= 16, false)
    error_message = "The hybrid stage requires vpn_shared_key of at least 16 characters."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "alert_email" {
  description = "Optional action-group email receiver. Null keeps alerts in Azure without sending email."
  type        = string
  default     = null
}
