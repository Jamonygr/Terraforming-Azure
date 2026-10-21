resource "terraform_data" "readiness" {
  input = {
    address_spaces = var.approved_address_spaces
    readiness      = var.cost_reviewed && var.quota_reviewed && var.cleanup_owner_confirmed
    decisions      = ["regional classic hub-and-three-spoke", "one-capstone-state", "independent-bootstrap", "WAF-to-private-IIS", "centralized-firewall", "two-gateway-simulated-site"]
  }
}
