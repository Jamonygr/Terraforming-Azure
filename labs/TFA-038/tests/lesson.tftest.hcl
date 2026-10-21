run "local_contract" {
  command = plan
  assert {
    condition     = terraform_data.record.input.recovery_key == "TFA-038"
    error_message = "The local resource must have stable recovery metadata."
  }
}
