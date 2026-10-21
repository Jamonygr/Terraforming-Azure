resource "azurerm_subnet" "resolver_outbound" {
  name                 = "snet-dns-outbound"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.31.1.16/28"]
  delegation {
    name = "resolver"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "lab" {
  name                    = "outbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.lab.id
  location                = azurerm_resource_group.lab.location
  subnet_id               = azurerm_subnet.resolver_outbound.id
  tags                    = local.tags
}

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "corp" {
  name                                       = "rules-${var.name_prefix}-corp"
  resource_group_name                        = azurerm_resource_group.lab.name
  location                                   = azurerm_resource_group.lab.location
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.lab.id]
  tags                                       = local.tags
}

resource "azurerm_private_dns_resolver_forwarding_rule" "corp" {
  name                      = "corp-training"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.corp.id
  domain_name               = "corp.tfa.internal."
  enabled                   = true
  target_dns_servers {
    ip_address = "10.131.2.4"
    port       = 53
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "azure" {
  name                      = "azure-clients"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.corp.id
  virtual_network_id        = azurerm_virtual_network.azure.id
}

module "azure_probe" {
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-probe"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.azure_workload.id
  admin_password      = var.admin_password
  bootstrap_command   = ""
  tags                = local.tags
}

output "azure_probe_vm_name" { value = module.azure_probe.name }
output "corporate_hostname" { value = "files.corp.tfa.internal" }
output "corporate_expected_ip" { value = "10.131.2.4" }
