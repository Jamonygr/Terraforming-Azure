output "resource_group_name" { value = azurerm_resource_group.lab.name }
output "stage" { value = var.stage }
output "virtual_network_ids" { value = { for key, value in azurerm_virtual_network.network : key => value.id } }
output "subnets" { value = { for key, value in azurerm_subnet.subnet : key => { id = value.id, prefix = value.address_prefixes[0] } } }
output "firewall_private_ip" { value = local.secure ? azurerm_firewall.hub[0].ip_configuration[0].private_ip_address : null }
output "resolver_inbound_ip" { value = local.secure ? local.resolver_ip : null }
output "app_gateway_public_ip" { value = local.apps ? azurerm_public_ip.ingress[0].ip_address : null }
output "app_gateway_name" { value = local.apps ? azurerm_application_gateway.ingress[0].name : null }
output "app_host" { value = local.app_host }
output "bastion_name" { value = local.secure ? azurerm_bastion_host.hub[0].name : null }
output "vm_names" { value = { for key, value in azurerm_windows_virtual_machine.vm : key => value.name } }
output "vm_ids" { value = { for key, value in azurerm_windows_virtual_machine.vm : key => value.id } }
output "vm_private_ips" { value = { for key, value in local.vms : key => value.address } }
output "nic_names" { value = { for key, value in azurerm_network_interface.vm : key => value.name } }
output "storage_account_name" { value = local.apps ? azurerm_storage_account.data[0].name : null }
output "key_vault_name" { value = local.apps ? azurerm_key_vault.data[0].name : null }
output "vpn_connection_names" { value = { for key, value in azurerm_virtual_network_gateway_connection.vpn : key => value.name } }
output "workspace_name" { value = azurerm_log_analytics_workspace.lab.name }
output "workspace_customer_id" { value = azurerm_log_analytics_workspace.lab.workspace_id }
locals {
  # These facts describe the managed resources, not independent design constants.
  evidence_route_associations = concat(values(azurerm_subnet_route_table_association.workload), azurerm_subnet_route_table_association.gateway)
  evidence_default_tables     = [for route in values(azurerm_route.default) : route.route_table_name if route.address_prefix == "0.0.0.0/0"]
  evidence_peerings           = concat(values(azurerm_virtual_network_peering.hub_to_spoke), values(azurerm_virtual_network_peering.spoke_to_hub))
}

output "traffic_contract" {
  description = "Resource-derived configuration evidence only. This does not establish Azure runtime behavior."
  value = {
    ingress_forced_tunnel = anytrue([
      for association in local.evidence_route_associations :
      association.subnet_id == azurerm_subnet.subnet["ingress"].id &&
      anytrue([for table in values(azurerm_route_table.workload) : table.id == association.route_table_id && contains(local.evidence_default_tables, table.name)])
    ])
    spoke_direct_peerings = length([
      for peer in local.evidence_peerings : peer
      if peer.virtual_network_name != azurerm_virtual_network.network["hub"].name && peer.remote_virtual_network_id != azurerm_virtual_network.network["hub"].id
    ])
    private_endpoint_policy = azurerm_subnet.subnet["data"].private_endpoint_network_policies
    gateway_default_route   = anytrue([for route in values(azurerm_route.gateway_to_spokes) : route.address_prefix == "0.0.0.0/0"])
    firewall_sku            = local.secure ? azurerm_firewall.hub[0].sku_tier : null
    windows_vm_count        = length(azurerm_windows_virtual_machine.vm)
    vpn_gateway_count       = length(azurerm_virtual_network_gateway.vpn)
    public_vm_count         = length([for nic in values(azurerm_network_interface.vm) : nic if anytrue([for ip in nic.ip_configuration : ip.public_ip_address_id != null])])
  }
}

output "private_endpoint_ips" {
  description = "Actual private service connection addresses; use these exact targets in DNS probes."
  value       = { for key, endpoint in azurerm_private_endpoint.data : key => one(endpoint.private_service_connection).private_ip_address }
}

output "evidence_targets" {
  description = "Non-secret configuration targets for the stage-aware evidence runner."
  value = {
    virtual_networks       = { for key, network in azurerm_virtual_network.network : key => { name = network.name, id = network.id, prefixes = network.address_space } }
    subnet_ids             = { for key, subnet in azurerm_subnet.subnet : key => subnet.id }
    subnet_prefixes        = { for key, subnet in azurerm_subnet.subnet : key => subnet.address_prefixes[0] }
    private_zones          = [for zone in azurerm_private_dns_zone.zone : zone.name]
    route_tables           = merge({ for key, table in azurerm_route_table.workload : key => table.name }, local.hybrid ? { gateway = azurerm_route_table.gateway[0].name } : {})
    firewall_name          = local.secure ? azurerm_firewall.hub[0].name : null
    firewall_policy_name   = local.secure ? azurerm_firewall_policy.hub[0].name : null
    private_endpoint_names = { for key, endpoint in azurerm_private_endpoint.data : key => endpoint.name }
    workload_principals    = { for key, vm in azurerm_windows_virtual_machine.vm : key => vm.identity[0].principal_id }
  }
}
