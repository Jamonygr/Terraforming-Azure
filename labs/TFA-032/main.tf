locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-032", managed_by = "Terraform"
    }
  )
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_role_assignment" "reader" {
  scope                = azurerm_resource_group.lab.id
  role_definition_name = "Reader"
  principal_id         = var.reader_principal_id
}

resource "azurerm_policy_definition" "tag" {
  name         = "${var.name_prefix}-require-course-tag"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Lab: resources must carry course tag"
  policy_rule = jsonencode({
    if = {
      field = "tags['course']", exists = "false"
    }

    then = {
      effect = "deny"
    }
    }
  )
}

resource "azurerm_resource_group_policy_assignment" "tag" {
  name                 = "require-course-tag"
  resource_group_id    = azurerm_resource_group.lab.id
  policy_definition_id = azurerm_policy_definition.tag.id
  description          = "Only this lab resource group; does not assign at subscription scope."
}

resource "azurerm_consumption_budget_resource_group" "lab" {
  name              = "budget-${var.name_prefix}"
  resource_group_id = azurerm_resource_group.lab.id
  amount            = var.monthly_budget
  time_grain        = "Monthly"
  time_period {
    start_date = var.budget_start_date
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    contact_emails = [var.notification_email]
  }
}

resource "azurerm_management_lock" "delete" {
  count      = var.enable_delete_lock ? 1 : 0
  name       = "protect-lab"
  scope      = azurerm_resource_group.lab.id
  lock_level = "CanNotDelete"
  notes      = "Exercise only. Set enable_delete_lock=false and apply before destroying."
}
