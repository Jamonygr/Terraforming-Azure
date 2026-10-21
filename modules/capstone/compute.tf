resource "azurerm_network_interface" "vm" {
  for_each            = local.vms
  name                = "nic-${local.prefix}-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.subnet[each.value.subnet].id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.address
  }
  tags = local.tags
}

resource "azurerm_windows_virtual_machine" "vm" {
  for_each              = local.vms
  name                  = "vm-${local.prefix}-${each.key}"
  computer_name         = each.key
  location              = var.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = each.value.size
  admin_username        = "azureadmin"
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.vm[each.key].id]
  provision_vm_agent    = true
  patch_mode            = "AutomaticByOS"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  tags = local.tags
  depends_on = [
    azurerm_virtual_network_dns_servers.spokes,
    azurerm_subnet_network_security_group_association.workload,
    azurerm_subnet_route_table_association.workload,
    azurerm_firewall_policy_rule_collection_group.lab,
    azurerm_private_dns_zone_virtual_network_link.hub,
    azurerm_virtual_network_peering.spoke_to_hub
    , azurerm_subnet_nat_gateway_association.onprem
  ]
}

resource "azurerm_virtual_machine_extension" "iis" {
  for_each                   = local.apps ? toset(local.app_vm_keys) : toset([])
  name                       = "ConfigureIIS"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm[each.key].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  settings = jsonencode({
    commandToExecute = "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(file("${path.module}/templates/Configure-Iis.ps1"), "UTF-16LE")}"
  })
  tags = local.tags
}

resource "azurerm_virtual_machine_extension" "corp_dns" {
  count                      = local.hybrid ? 1 : 0
  name                       = "ConfigureCorpDNS"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm["corp01"].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  settings = jsonencode({
    commandToExecute = "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(templatefile("${path.module}/templates/Configure-CorpDns.ps1.tftpl", { resolver_ip = local.resolver_ip, corp_ip = local.corp_dns_ip }), "UTF-16LE")}"
  })
  tags       = local.tags
  depends_on = [azurerm_virtual_network_gateway_connection.vpn]
}
