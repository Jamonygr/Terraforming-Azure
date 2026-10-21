locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-028", managed_by = "Terraform"
    }
  )
  suffix = substr(sha256("${var.subscription_id}:${var.name_prefix}:${var.location}"), 0, 8)
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
  address_space       = ["10.28.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "ops" {
  name                 = "snet-ops"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.28.1.0/24"]
}

module "ops" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-ops"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.ops.id
  admin_password      = var.admin_password
  bootstrap_command   = ""

  tags = local.tags
}

resource "azurerm_log_analytics_workspace" "lab" {
  name                = "law-${var.name_prefix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1
  tags                = local.tags
}

resource "azurerm_monitor_data_collection_rule" "windows" {
  name                = "dcr-${var.name_prefix}-windows"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  kind                = "Windows"
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.lab.id
      name                  = "workspace"
    }
  }

  data_sources {
    windows_event_log {
      name           = "windows-events"
      streams        = ["Microsoft-Event"]
      x_path_queries = ["System!*[System[(Level=1 or Level=2 or Level=3)]]", "Application!*[System[(Level=1 or Level=2 or Level=3)]]"]
    }

    performance_counter {
      name                          = "performance"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = ["\\Processor(_Total)\\% Processor Time", "\\Memory\\Available MBytes"]
    }
  }

  data_flow {
    streams      = ["Microsoft-Event", "Microsoft-Perf"]
    destinations = ["workspace"]
  }

  tags = local.tags
}

resource "azurerm_virtual_machine_extension" "ama" {
  depends_on                 = [azurerm_subnet_nat_gateway_association.ops, azurerm_nat_gateway_public_ip_association.ops]
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = module.ops.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  tags                       = local.tags
}

resource "azurerm_monitor_data_collection_rule_association" "ops" {
  name                    = "windows-to-workspace"
  target_resource_id      = module.ops.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.windows.id
}

resource "azurerm_public_ip" "nat" {
  name                = "pip-${var.name_prefix}-nat"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "ops" {
  name                = "nat-${var.name_prefix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "ops" {
  nat_gateway_id       = azurerm_nat_gateway.ops.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "ops" {
  subnet_id      = azurerm_subnet.ops.id
  nat_gateway_id = azurerm_nat_gateway.ops.id
}

data "azurerm_client_config" "current" {}
resource "azurerm_key_vault" "audit" {
  name                       = "kv-${var.name_prefix}-${local.suffix}"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}
resource "azurerm_monitor_diagnostic_setting" "vault" {
  name                           = "keyvault-audit-to-workspace"
  target_resource_id             = azurerm_key_vault.audit.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.lab.id
  log_analytics_destination_type = "Dedicated"
  enabled_log { category_group = "allLogs" }
  enabled_metric { category = "AllMetrics" }
}
