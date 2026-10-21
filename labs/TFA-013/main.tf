resource "azurerm_resource_group" "lab" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

output "resource_group_name" {
  description = "Resource group owned by this independent lab."
  value       = azurerm_resource_group.lab.name
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.15.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "workload" {
  name                            = "workload"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = ["10.15.1.0/24"]
  default_outbound_access_enabled = false
}

output "vnet_name" {
  description = "VNet name for CLI inspection."
  value       = azurerm_virtual_network.lab.name
}

output "subnet_id" {
  description = "Workload subnet resource ID."
  value       = azurerm_subnet.workload.id
}
resource "azurerm_network_interface" "vm" {
  name                = "${var.name_prefix}-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
  ip_configuration {
    name                          = "private"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "lab" {
  name                  = "${var.name_prefix}-vm"
  computer_name         = "${replace(var.name_prefix, "-", "")}vm"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.vm_size
  admin_username        = "tfalearner"
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.vm.id]
  provision_vm_agent    = true
  tags                  = local.tags
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

output "vm_name" {
  description = "Private Windows VM for CLI Run Command and administration exercises."
  value       = azurerm_windows_virtual_machine.lab.name
}

output "nic_name" {
  description = "NIC for effective route and NSG inspection."
  value       = azurerm_network_interface.vm.name
}

output "private_ip_address" {
  description = "Private address; the VM has no public IP."
  value       = azurerm_network_interface.vm.private_ip_address
}

resource "azurerm_route_table" "workload" {
  name                = "${var.name_prefix}-routes"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
}

resource "azurerm_route" "discard" {
  name                = "discard-lab-destination"
  resource_group_name = azurerm_resource_group.lab.name
  route_table_name    = azurerm_route_table.workload.name
  address_prefix      = "10.60.0.0/16"
  next_hop_type       = "None"
}

resource "azurerm_subnet_route_table_association" "workload" {
  subnet_id      = azurerm_subnet.workload.id
  route_table_id = azurerm_route_table.workload.id
}

output "route_table_name" {
  description = "A deliberate discard route demonstrates effective routing without a fake appliance."
  value       = azurerm_route_table.workload.name
}
