module "network" {
  source        = "../../modules/learning-network"
  name_prefix   = var.name_prefix
  location      = var.location
  tags          = local.tags
  address_space = ["10.21.0.0/16"]
  subnets       = { web = "10.21.1.0/24", app = "10.21.2.0/24" }
}

output "resource_group_name" {
  description = "Resource group created by the network module."
  value       = module.network.resource_group_name
}

output "vnet_name" {
  description = "Network module output, exposed through the root."
  value       = module.network.vnet_name
}

output "subnet_ids" {
  description = "Stable keys provide a documented module interface."
  value       = module.network.subnet_ids
}
