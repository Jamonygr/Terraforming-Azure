resource "azurerm_log_analytics_workspace" "lab" {
  name                = "law-${local.prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1
  tags                = local.tags
}

resource "azurerm_monitor_action_group" "lab" {
  name                = "ag-${local.prefix}"
  resource_group_name = azurerm_resource_group.lab.name
  short_name          = "tfazure"
  dynamic "email_receiver" {
    for_each = var.alert_email == null ? [] : [var.alert_email]
    content {
      name                    = "lab-operator"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
  tags = local.tags
}

locals {
  diagnostics = merge(
    local.secure ? { firewall = azurerm_firewall.hub[0].id, bastion = azurerm_bastion_host.hub[0].id } : {},
    local.apps ? {
      ingress = azurerm_application_gateway.ingress[0].id
      vault   = azurerm_key_vault.data[0].id
      blob    = "${azurerm_storage_account.data[0].id}/blobServices/default"
    } : {},
    { for key, value in azurerm_virtual_network_gateway.vpn : "vpn-${key}" => value.id }
  )
}

data "azurerm_monitor_diagnostic_categories" "resource" {
  for_each    = local.diagnostics
  resource_id = each.value
}

resource "azurerm_monitor_diagnostic_setting" "resource" {
  for_each                       = local.diagnostics
  name                           = "to-capstone-workspace"
  target_resource_id             = each.value
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.lab.id
  log_analytics_destination_type = "Dedicated"
  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.resource[each.key].log_category_types
    content {
      category = enabled_log.value
    }
  }
  dynamic "enabled_metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.resource[each.key].metrics
    content {
      category = enabled_metric.value
    }
  }
}

resource "azurerm_virtual_machine_extension" "ama" {
  for_each                   = local.vms
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm[each.key].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  settings                   = jsonencode({})
  tags                       = local.tags
  # Serialize extensions per VM behind role installation.
  depends_on = [azurerm_virtual_machine_extension.iis, azurerm_virtual_machine_extension.corp_dns]
}

resource "azurerm_monitor_data_collection_rule" "windows" {
  count                       = local.apps ? 1 : 0
  name                        = "dcr-${local.prefix}-windows"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.lab.name
  kind                        = "Windows"
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.windows[0].id
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.lab.id
      name                  = "workspace"
    }
  }
  data_sources {
    windows_event_log {
      name           = "windows-errors"
      streams        = ["Microsoft-Event"]
      x_path_queries = ["System!*[System[(Level=1 or Level=2 or Level=3)]]", "Application!*[System[(Level=1 or Level=2 or Level=3)]]"]
    }
    performance_counter {
      name                          = "windows-performance"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = ["\\Processor(_Total)\\% Processor Time", "\\Memory\\Available MBytes"]
    }
    iis_log {
      name            = "iis-access"
      streams         = ["Microsoft-W3CIISLog"]
      log_directories = ["C:\\inetpub\\logs\\LogFiles\\W3SVC1"]
    }
  }
  data_flow {
    streams      = ["Microsoft-Event", "Microsoft-Perf", "Microsoft-W3CIISLog"]
    destinations = ["workspace"]
  }
  tags = local.tags
}

resource "azurerm_monitor_data_collection_endpoint" "windows" {
  count                         = local.apps ? 1 : 0
  name                          = "dce-${local.prefix}-windows"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.lab.name
  kind                          = "Windows"
  public_network_access_enabled = true
  description                   = "Approved HTTPS monitoring egress for IIS log ingestion; private workload data remains separate."
  tags                          = local.tags
}

resource "azurerm_monitor_data_collection_rule_association" "windows" {
  for_each                = local.vms
  name                    = "windows-telemetry"
  target_resource_id      = azurerm_windows_virtual_machine.vm[each.key].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.windows[0].id
}

resource "azurerm_monitor_metric_alert" "unhealthy_backend" {
  count               = local.apps ? 1 : 0
  name                = "alert-${local.prefix}-unhealthy-iis"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_application_gateway.ingress[0].id]
  description         = "One or more private IIS backends is unhealthy. Restore IIS and /health.txt."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }
  action {
    action_group_id = azurerm_monitor_action_group.lab.id
  }
  tags = local.tags
}
