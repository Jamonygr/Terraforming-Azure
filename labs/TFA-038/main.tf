resource "terraform_data" "record" {
  input = {
    message = var.message, recovery_key = "TFA-038"
  }
}
