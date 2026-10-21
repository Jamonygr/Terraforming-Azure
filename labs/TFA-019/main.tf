locals {
  environments = {
    dev  = { address_space = "10.19.0.0/16", approval = "learner" }
    prod = { address_space = "10.119.0.0/16", approval = "reviewer" }
  }
}

output "environment_design" {
  description = "Local design preview; each environments directory has its own independent local state."
  value       = local.environments
}
