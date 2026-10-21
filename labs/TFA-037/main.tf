resource "terraform_data" "workflow_contract" {
  input = {
    operation = var.operation, workflow = ".github/workflows/azure.yml", review_required = true, saved_plan_required = true
  }
}
