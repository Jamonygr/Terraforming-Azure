# Alert on the synthetic event, not on unrelated platform noise.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "synthetic_event" {
  name                    = "alert-${var.name_prefix}-synthetic-event"
  location                = azurerm_resource_group.lab.location
  resource_group_name     = azurerm_resource_group.lab.name
  scopes                  = [azurerm_log_analytics_workspace.lab.id]
  description             = "Training alert: TFA-028 Application ERROR event observed during the last five minutes."
  severity                = 3
  enabled                 = true
  evaluation_frequency    = "PT1M"
  window_duration         = "PT5M"
  auto_mitigation_enabled = true
  criteria {
    query                   = <<-KQL
      Event
      | where EventLog == "Application" and EventLevelName == "Error"
      | where RenderedDescription contains "TFA-028 monitoring evidence"
    KQL
    time_aggregation_method = "Count"
    operator                = "GreaterThanOrEqual"
    threshold               = 1
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }
  tags = local.tags
}

output "synthetic_alert_id" {
  value = azurerm_monitor_scheduled_query_rules_alert_v2.synthetic_event.id
}
