variable "enable_probes" {
  description = "Optional paid packet exercise after TFA-010; creates two private Windows VMs."
  type        = bool
  default     = false
}
variable "probe_admin_password" {
  description = "Only required when enable_probes=true; supply via TF_VAR_probe_admin_password."
  type        = string
  sensitive   = true
  default     = null
  validation {
    condition     = var.probe_admin_password == null ? !var.enable_probes : length(var.probe_admin_password) >= 14
    error_message = "Optional probes require a Windows password of at least 14 characters."
  }
}
variable "web_membership_enabled" {
  description = "Remove the server from the ASG to demonstrate that the same allow rule no longer matches."
  type        = bool
  default     = true
}
module "probe" {
  for_each            = var.enable_probes ? toset(["client", "server"]) : toset([])
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.workload.id
  admin_password      = var.probe_admin_password
  bootstrap_command   = ""
  tags                = local.tags
}
resource "azurerm_network_interface_application_security_group_association" "web" {
  count                         = var.enable_probes && var.web_membership_enabled ? 1 : 0
  network_interface_id          = module.probe["server"].network_interface_id
  application_security_group_id = azurerm_application_security_group.web.id
}
output "probe_targets" {
  value = { for key, vm in module.probe : key => { name = vm.name, ip = vm.private_ip_address, nic = vm.network_interface_id } }
}
