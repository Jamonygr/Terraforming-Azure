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
output "traffic_contract" {
  description = "Plan-time evidence of intended enforcement. Verify live effective routes and logs after deployment."
  value = {
    ingress_forced_tunnel   = false
    spoke_direct_peerings   = 0
    private_endpoint_policy = "Enabled"
    gateway_default_route   = false
    firewall_sku            = local.secure ? "Standard" : null
    windows_vm_count        = length(local.vms)
    vpn_gateway_count       = length(azurerm_virtual_network_gateway.vpn)
    public_vm_count         = 0
  }
}
