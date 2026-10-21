variable "networks" {
  description = "Each key becomes a network-module address and independent resource group."
  type        = map(object({ address_space = list(string), subnets = map(string) }))
  default = {
    hub   = { address_space = ["10.20.0.0/16"], subnets = { services = "10.20.1.0/24" } }
    spoke = { address_space = ["10.21.0.0/16"], subnets = { web = "10.21.1.0/24", app = "10.21.2.0/24" } }
  }
  validation {
    condition     = length(var.networks) >= 1 && alltrue([for name in keys(var.networks) : can(regex("^[a-z][a-z0-9]{0,3}$", name))])
    error_message = "Use at least one network with a 1-to-4-character lowercase alphanumeric key."
  }
}

module "network" {
  for_each      = var.networks
  source        = "../../modules/learning-network"
  name_prefix   = "${var.name_prefix}-${each.key}"
  location      = var.location
  tags          = merge(local.tags, { network = each.key })
  address_space = each.value.address_space
  subnets       = each.value.subnets
}

output "networks" {
  description = "Structured module outputs retain each input key. There is no peering in this lesson."
  value       = { for name, net in module.network : name => { vnet_id = net.vnet_id, vnet_name = net.vnet_name, resource_group_name = net.resource_group_name, subnet_ids = net.subnet_ids } }
}

output "cleanup_group_names" {
  description = "Capture the exact groups owned by this root before destruction."
  value       = [for network in module.network : network.resource_group_name]
}
