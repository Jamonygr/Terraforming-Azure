mock_provider "azurerm" {}

variables {
  name_prefix   = "tfa-module"
  location      = "westeurope"
  address_space = ["10.20.0.0/16"]
  subnets       = { web = "10.20.1.0/24", app = "10.20.2.0/24" }
  tags          = { owner = "test" }
}

run "public_contract" {
  command = plan
  assert {
    condition     = output.vnet_name == "tfa-module-vnet" && output.resource_group_name == "tfa-module-rg"
    error_message = "Stable public names changed."
  }
  assert {
    condition     = toset(keys(output.subnet_ids)) == toset(["app", "web"])
    error_message = "Output keys must match input subnet keys."
  }
  assert {
    condition     = azurerm_virtual_network.network.tags["owner"] == "test"
    error_message = "Ownership tags were not propagated."
  }
  assert {
    condition     = alltrue([for subnet in azurerm_subnet.subnet : subnet.default_outbound_access_enabled == false])
    error_message = "Subnets must not rely on implicit default outbound access."
  }
}

run "adding_subnet_keeps_existing_keys" {
  command = plan
  variables { subnets = { web = "10.20.1.0/24", app = "10.20.2.0/24", data = "10.20.3.0/24" } }
  assert {
    condition     = toset(keys(output.subnet_ids)) == toset(["web", "app", "data"])
    error_message = "The module did not preserve the supplied subnet keys."
  }
}

run "reject_invalid_cidr" {
  command = plan
  variables { address_space = ["10.20.0.999/16"] }
  expect_failures = [var.address_space]
}

run "reject_empty_subnets" {
  command = plan
  variables { subnets = {} }
  expect_failures = [var.subnets]
}
