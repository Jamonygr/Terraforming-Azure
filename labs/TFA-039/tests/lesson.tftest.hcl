run "local_contract" {
  command = plan
  assert {
    condition     = terraform_data.readiness.input.readiness == false
    error_message = "Readiness must not be claimed before explicit review flags."
  }
  assert {
    condition     = length(terraform_data.readiness.input.address_spaces) == 5
    error_message = "The workshop requires hub, three spokes, and the simulated site."
  }
}
run "reviewed_readiness" {
  command = plan
  variables {
    cost_reviewed           = true
    quota_reviewed          = true
    cleanup_owner_confirmed = true
  }
  assert {
    condition     = terraform_data.readiness.input.readiness
    error_message = "All three explicit review flags should be recorded."
  }
}
