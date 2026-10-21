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
  address_space       = ["10.11.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "workload" {
  name                            = "workload"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = ["10.11.1.0/24"]
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
resource "azurerm_public_ip" "nat" {
  name                = "${var.name_prefix}-nat-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "lab" {
  name                = "${var.name_prefix}-nat"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "lab" {
  nat_gateway_id       = azurerm_nat_gateway.lab.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "lab" {
  subnet_id      = azurerm_subnet.workload.id
  nat_gateway_id = azurerm_nat_gateway.lab.id
}

output "outbound_public_ip" {
  description = "Explicit outbound source IP; this does not admit inbound connections."
  value       = azurerm_public_ip.nat.ip_address
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

resource "azurerm_subnet" "bastion" {
  name                            = "AzureBastionSubnet"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = ["10.11.0.0/26"]
  default_outbound_access_enabled = false
}

resource "azurerm_public_ip" "bastion" {
  name                = "${var.name_prefix}-bastion-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_bastion_host" "lab" {
  name                = "${var.name_prefix}-bastion"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Basic"
  tags                = local.tags
  ip_configuration {
    name                 = "bastion"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_security_group" "vm" {
  name                = "${var.name_prefix}-vm-nsg"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
  security_rule {
    name                       = "allow-bastion-rdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.11.0.0/26"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "deny-other-rdp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

output "bastion_name" {
  description = "Open this Bastion host in the portal and select the private VM."
  value       = azurerm_bastion_host.lab.name
}
