resource "azurerm_private_dns_zone" "zone" {
  for_each            = local.private_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each              = azurerm_private_dns_zone.zone
  name                  = "link-hub"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.network["hub"].id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_resolver" "hub" {
  count               = local.secure ? 1 : 0
  name                = "dnspr-${local.prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  virtual_network_id  = azurerm_virtual_network.network["hub"].id
  tags                = local.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "hub" {
  count                   = local.secure ? 1 : 0
  name                    = "inbound"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.hub[0].id
  ip_configurations {
    private_ip_allocation_method = "Static"
    private_ip_address           = local.resolver_ip
    subnet_id                    = azurerm_subnet.subnet["dns_in"].id
  }
  tags = local.tags
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "hub" {
  count                   = local.hybrid ? 1 : 0
  name                    = "outbound"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.hub[0].id
  subnet_id               = azurerm_subnet.subnet["dns_out"].id
  tags                    = local.tags
}

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "corp" {
  count                                      = local.hybrid ? 1 : 0
  name                                       = "dnsrules-${local.prefix}-corp"
  location                                   = var.location
  resource_group_name                        = azurerm_resource_group.lab.name
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.hub[0].id]
  tags                                       = local.tags
}

resource "azurerm_private_dns_resolver_forwarding_rule" "corp" {
  count                     = local.hybrid ? 1 : 0
  name                      = "corp-zone"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.corp[0].id
  domain_name               = "corp.terraforming-azure.test."
  enabled                   = true
  target_dns_servers {
    ip_address = local.corp_dns_ip
    port       = 53
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "hub" {
  count                     = local.hybrid ? 1 : 0
  name                      = "hub-corp-forwarding"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.corp[0].id
  virtual_network_id        = azurerm_virtual_network.network["hub"].id
}

resource "azurerm_private_dns_a_record" "vm" {
  for_each            = { for key, value in local.vms : key => value if key != "corp01" }
  name                = each.key
  zone_name           = azurerm_private_dns_zone.zone["azure"].name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 60
  records             = [each.value.address]
  tags                = local.tags
}
