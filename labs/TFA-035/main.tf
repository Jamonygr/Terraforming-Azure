resource "terraform_data" "pull_request_contract" {
  input = {
    branch = var.branch_name, workflow = ".github/workflows/quality.yml", required_checks = ["validate"], quality_gate_steps = ["format", "validate", "mock-tests", "course-integrity"]
  }
}
