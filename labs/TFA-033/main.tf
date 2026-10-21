locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-033", managed_by = "Terraform"
    }
  )
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

provider "azurerm" {
  alias           = "secondary"
  subscription_id = var.secondary_subscription_id
  features {
  }
}

resource "azurerm_resource_group" "secondary" {
  provider = azurerm.secondary
  name     = "rg-${var.name_prefix}-secondary"
  location = var.location
  tags     = local.tags
}
