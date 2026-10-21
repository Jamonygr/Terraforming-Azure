locals {
  prefix_lengths = {
    for name, route in var.candidate_routes : name => tonumber(split("/", route.prefix)[1])
  }

  longest_prefix = max(values(local.prefix_lengths)...)
  selected_routes = {
    for name, route in var.candidate_routes : name => route if local.prefix_lengths[name] == local.longest_prefix
  }
}

resource "terraform_data" "route_decision" {
  input = {
    destination = "10.130.2.4", selected = local.selected_routes, gateway_subnet_reserved = "10.30.0.0/27"
  }

  lifecycle {
    precondition {
      condition     = length(local.selected_routes) == 1
      error_message = "This introductory model requires exactly one most-specific route."
    }
  }
}
