locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-025", managed_by = "Terraform"
    }
  )
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.25.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.25.0.0/26"]
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.25.2.0/24"]
}

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.name_prefix}-firewall"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_firewall_policy" "lab" {
  name                     = "afwp-${var.name_prefix}"
  location                 = azurerm_resource_group.lab.location
  resource_group_name      = azurerm_resource_group.lab.name
  sku                      = "Standard"
  threat_intelligence_mode = "Alert"
  tags                     = local.tags
}

resource "azurerm_firewall" "lab" {
  name                = "afw-${var.name_prefix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.lab.id
  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = local.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "egress" {
  name               = "learning-egress"
  firewall_policy_id = azurerm_firewall_policy.lab.id
  priority           = 200
  application_rule_collection {
    name     = "allow-microsoft-https"
    priority = 200
    action   = "Allow"
    rule {
      name              = "docs-over-https"
      source_addresses  = ["10.25.2.0/24"]
      destination_fqdns = var.allow_learning_site ? ["learn.microsoft.com", "www.microsoft.com"] : ["never-allowed.terraforming-azure.test"]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_route_table" "egress" {
  name                = "rt-${var.name_prefix}-egress"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  route {
    name                   = "internet-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.lab.ip_configuration[0].private_ip_address
  }

  tags = local.tags
}

resource "azurerm_subnet_route_table_association" "workload" {
  subnet_id      = azurerm_subnet.workload.id
  route_table_id = azurerm_route_table.egress.id
}

module "probe" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-probe"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.workload.id
  admin_password      = var.admin_password

  tags = local.tags
}

resource "azurerm_log_analytics_workspace" "firewall" {
  name                = "law-${var.name_prefix}-firewall"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1
  tags                = local.tags
}
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                           = "application-decisions"
  target_resource_id             = azurerm_firewall.lab.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.firewall.id
  log_analytics_destination_type = "Dedicated"
  enabled_log { category = "AZFWApplicationRule" }
}
