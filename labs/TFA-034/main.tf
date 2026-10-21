locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-034", managed_by = "Terraform"
    }
  )
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.name_prefix}-main"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.34.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "client" {
  name                 = "snet-client"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.34.1.0/24"]
}

resource "azurerm_subnet" "server" {
  name                 = "snet-server"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.34.2.0/24"]
}

module "client" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-client"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.client.id
  admin_password      = var.admin_password
  bootstrap_command   = ""

  tags = local.tags
}

module "server" {
  depends_on          = [azurerm_subnet_nat_gateway_association.probe, azurerm_nat_gateway_public_ip_association.probe]
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-server"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.server.id
  admin_password      = var.admin_password
  private_ip_address  = "10.34.2.4"
  bootstrap_command   = "Install-WindowsFeature Web-Server -IncludeManagementTools; if (-not (Get-NetFirewallRule -DisplayName 'Lab IIS HTTP' -ErrorAction SilentlyContinue)) { New-NetFirewallRule -DisplayName 'Lab IIS HTTP' -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow }; ${var.incident == "app-stopped" ? "Stop-Service W3SVC -Force" : "Start-Service W3SVC"}"

  tags = local.tags
}

resource "azurerm_network_security_group" "server" {
  name                = "nsg-${var.name_prefix}-server"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  security_rule {
    name                       = "exercise-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = var.incident == "nsg-block" ? "Deny" : "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.34.1.0/24"
    destination_address_prefix = "10.34.2.0/24"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "server" {
  subnet_id                 = azurerm_subnet.server.id
  network_security_group_id = azurerm_network_security_group.server.id
}
