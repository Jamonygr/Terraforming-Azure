variable "enable_probes" {
  description = "Optional paid topology: one private Windows probe in each VNet and hub/isolated peering."
  type        = bool
  default     = false
}
variable "probe_admin_password" {
  description = "Only required for optional probe VMs; use TF_VAR_probe_admin_password."
  type        = string
  sensitive   = true
  default     = null
  validation {
    condition     = var.probe_admin_password == null ? !var.enable_probes : length(var.probe_admin_password) >= 14
    error_message = "Optional probes require a Windows password of at least 14 characters."
  }
}
resource "azurerm_subnet" "probe" {
  for_each                        = var.enable_probes ? local.networks : {}
  name                            = "probe"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.network[each.key].name
  address_prefixes                = [cidrsubnet(each.value, 8, 1)]
  default_outbound_access_enabled = false
}
module "probe" {
  for_each            = var.enable_probes ? local.networks : {}
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.probe[each.key].id
  admin_password      = var.probe_admin_password
  bootstrap_command   = ""
  tags                = local.tags
}
output "probe_targets" {
  value = { for key, vm in module.probe : key => { name = vm.name, ip = vm.private_ip_address, nic = vm.network_interface_id } }
}
