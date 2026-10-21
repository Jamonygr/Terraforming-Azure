mock_provider "azurerm" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  name_prefix     = "tfa021"
}

run "names_are_stable" {
  command = plan
  assert {
    condition     = module.network.vnet_name == "tfa021-vnet"
    error_message = "The public VNet naming contract changed."
  }
  assert {
    condition     = module.network.resource_group_name == "tfa021-rg"
    error_message = "The public resource-group naming contract changed."
  }
}

run "subnet_keys_are_stable" {
  command = plan
  assert {
    condition     = toset(keys(module.network.subnet_ids)) == toset(["web", "app"])
    error_message = "The network must expose both expected subnet keys."
  }
}

run "reject_bad_prefix" {
  command = plan
  variables { name_prefix = "INVALID PREFIX" }
  expect_failures = [var.name_prefix]
}
