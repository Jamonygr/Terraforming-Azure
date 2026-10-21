terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm", version = ">= 4.0.0, < 5.0.0"
    }
  }
}

variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "private_ip_address" {
  type    = string
  default = null
}

variable "bootstrap_command" {
  type    = string
  default = ""
}

variable "identity_ids" {
  description = "Optional user-assigned identity resource IDs attached in addition to the system identity."
  type        = set(string)
  default     = []
}
variable "tags" {
  type = map(string)
  default = {
  }
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address == null ? "Dynamic" : "Static"
    private_ip_address            = var.private_ip_address
  }

  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                       = "vm-${var.name}"
  computer_name              = substr(replace(var.name, "-", ""), 0, 15)
  location                   = var.location
  resource_group_name        = var.resource_group_name
  size                       = "Standard_B2s"
  admin_username             = "labadmin"
  admin_password             = var.admin_password
  network_interface_ids      = [azurerm_network_interface.vm.id]
  provision_vm_agent         = true
  allow_extension_operations = true
  identity {
    type         = length(var.identity_ids) == 0 ? "SystemAssigned" : "SystemAssigned, UserAssigned"
    identity_ids = var.identity_ids
  }

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

  boot_diagnostics {
  }

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "bootstrap" {
  count                      = var.bootstrap_command == "" ? 0 : 1
  name                       = "bootstrap"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  settings = jsonencode({
    commandToExecute = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"${var.bootstrap_command}\""
    }
  )
  tags = var.tags
}

output "id" {
  value = azurerm_windows_virtual_machine.vm.id
}

output "name" {
  value = azurerm_windows_virtual_machine.vm.name
}

output "private_ip_address" {
  value = azurerm_network_interface.vm.private_ip_address
}

output "network_interface_id" {
  value = azurerm_network_interface.vm.id
}

output "principal_id" {
  value = azurerm_windows_virtual_machine.vm.identity[0].principal_id
}
