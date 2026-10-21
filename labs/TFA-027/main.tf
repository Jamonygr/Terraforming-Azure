locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-027", managed_by = "Terraform"
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
  address_space       = ["10.27.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "gateway" {
  name                 = "snet-appgateway"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.27.0.0/24"]
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.27.1.0/24"]
}

module "web1" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-web1"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.web.id
  admin_password      = var.admin_password
  bootstrap_command   = "Install-WindowsFeature Web-Server -IncludeManagementTools; Set-Content -Path C:\\inetpub\\wwwroot\\index.html -Value 'Terraforming Azure - web1'; New-NetFirewallRule -DisplayName 'Lab IIS HTTP' -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow"

  tags = local.tags
}

module "web2" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-web2"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.web.id
  admin_password      = var.admin_password
  bootstrap_command   = "Install-WindowsFeature Web-Server -IncludeManagementTools; Set-Content -Path C:\\inetpub\\wwwroot\\index.html -Value 'Terraforming Azure - web2'; New-NetFirewallRule -DisplayName 'Lab IIS HTTP' -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow"

  tags = local.tags
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-${var.name_prefix}-web"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  security_rule {
    name                       = "allow-appgateway-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.27.0.0/24"
    destination_address_prefix = "10.27.1.0/24"
  }

  security_rule {
    name                       = "deny-other-vnet-inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "10.27.1.0/24"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_public_ip" "gateway" {
  name                = "pip-${var.name_prefix}-waf"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_web_application_firewall_policy" "lab" {
  name                = "waf-${var.name_prefix}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  tags = local.tags
}

resource "azurerm_application_gateway" "lab" {
  name                = "agw-${var.name_prefix}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.lab.id
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gateway"
    subnet_id = azurerm_subnet.gateway.id
  }

  frontend_port {
    name = "https"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  ssl_certificate {
    name     = "lab"
    data     = filebase64(var.certificate_path)
    password = var.certificate_password
  }

  backend_address_pool {
    name         = "iis"
    ip_addresses = [module.web1.private_ip_address, module.web2.private_ip_address]
  }

  probe {
    name                = "iis-health"
    protocol            = "Http"
    host                = "app.terraforming-azure.test"
    path                = "/"
    interval            = 30
    timeout             = 10
    unhealthy_threshold = 3
  }

  backend_http_settings {
    name                  = "http-to-iis"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "iis-health"
  }

  http_listener {
    name                           = "https"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "https"
    protocol                       = "Https"
    host_name                      = "app.terraforming-azure.test"
    ssl_certificate_name           = "lab"
  }

  request_routing_rule {
    name                       = "iis"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "https"
    backend_address_pool_name  = "iis"
    backend_http_settings_name = "http-to-iis"
  }

  tags       = local.tags
  depends_on = [module.web1, module.web2]
}
