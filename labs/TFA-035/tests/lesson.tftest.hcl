run "local_contract" {
  command = plan
  assert {
    condition     = terraform_data.pull_request_contract.input.workflow == ".github/workflows/quality.yml"
    error_message = "The contract must point to the real quality workflow."
  }
}
