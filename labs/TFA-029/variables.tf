variable "candidate_routes" {
  description = "Routes already known to match destination 10.130.2.4. This exercise models longest-prefix selection, not real packet forwarding."
  type = map(object({
    prefix = string, next_hop = string
    }
  ))
  default = {
    default = {
      prefix = "0.0.0.0/0", next_hop = "Internet"
    }

    remote = {
      prefix = "10.130.0.0/16", next_hop = "VirtualNetworkGateway"
    }
  }
}
