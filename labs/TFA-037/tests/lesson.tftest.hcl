run "local_contract" {
  command = plan
  assert {
    condition     = terraform_data.workflow_contract.input.operation == "plan" && terraform_data.workflow_contract.input.saved_plan_required
    error_message = "The safe default operation is a reviewed plan."
  }
}
