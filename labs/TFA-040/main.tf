provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  features {
    storage {
      # ARM-only control plane from public local/CI runners. Seed via ops01.
      data_plane_available = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

module "capstone" {
  source               = "../../modules/capstone"
  location             = var.location
  name_prefix          = var.name_prefix
  environment          = var.environment
  stage                = var.stage
  address_plan         = var.address_plan
  operator_cidrs       = var.operator_cidrs
  admin_password       = var.admin_password
  certificate_path     = var.certificate_path
  certificate_password = var.certificate_password
  vpn_shared_key       = var.vpn_shared_key
  alert_email          = var.alert_email
  tags                 = var.tags
}
