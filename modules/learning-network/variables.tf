variable "name_prefix" {
  description = "Stable, lowercase network identity. Changing it changes Azure resource names."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name_prefix))
    error_message = "Use a 3-to-20-character lowercase alphanumeric/hyphen prefix starting with a letter."
  }
}

variable "location" {
  description = "Azure location; moving a VNet to another region replaces it."
  type        = string
}

variable "tags" {
  description = "Non-secret ownership, lifecycle, and cost tags."
  type        = map(string)
  default     = {}
}

variable "address_space" {
  description = "One or more valid IPv4 CIDRs; plan globally to avoid overlaps."
  type        = list(string)
  default     = ["10.20.0.0/16"]
  validation {
    condition     = length(var.address_space) > 0 && alltrue([for cidr in var.address_space : can(cidrnetmask(cidr))])
    error_message = "Supply at least one valid IPv4 network CIDR."
  }
}

variable "subnets" {
  description = "Stable subnet name => IPv4 CIDR map. Prefixes must fit the VNet and must not overlap."
  type        = map(string)
  validation {
    condition     = length(var.subnets) > 0 && alltrue([for prefix in values(var.subnets) : can(cidrnetmask(prefix))])
    error_message = "Supply at least one subnet and valid IPv4 CIDRs."
  }
}
