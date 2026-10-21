mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "11111111-1111-1111-1111-111111111111"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/tfa-state-rg/providers/Microsoft.Storage/storageAccounts/tfastate1234567890"
    }
  }
}
variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}
run "maximum_prefix_fits_storage_name" {
  command = plan
  variables { name_prefix = "abcdefghi" }
  assert {
    condition     = length(azurerm_storage_account.state.name) == 24
    error_message = "The longest supported prefix must fit Azure's 24-character account limit."
  }
  assert {
    condition     = azurerm_storage_account.state.shared_access_key_enabled == false
    error_message = "Backend shared keys must remain disabled."
  }
}
run "additional_oidc_preserves_operator" {
  command = plan
  variables { backend_principal_id = "33333333-3333-3333-3333-333333333333" }
  assert {
    condition     = azurerm_role_assignment.operator.principal_id == "11111111-1111-1111-1111-111111111111" && length(azurerm_role_assignment.oidc) == 1
    error_message = "Granting OIDC access must not replace the operator's data-plane access."
  }
}
run "reject_overlong_prefix" {
  command = plan
  variables { name_prefix = "abcdefghij" }
  expect_failures = [var.name_prefix]
}
