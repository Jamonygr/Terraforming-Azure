run "local_contract" {
  command = plan
  assert {
    condition     = local.longest_prefix == 16 && keys(local.selected_routes) == ["remote"]
    error_message = "The matching /16 route must beat the internet default."
  }
}
