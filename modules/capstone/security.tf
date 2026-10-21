resource "azurerm_public_ip" "firewall" {
  count               = local.secure ? 1 : 0
  name                = "pip-${local.prefix}-firewall"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_firewall_policy" "hub" {
  count                    = local.secure ? 1 : 0
  name                     = "afwp-${local.prefix}"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.lab.name
  sku                      = "Standard"
  threat_intelligence_mode = "Alert"
  dns {
    proxy_enabled = true
    servers       = [local.resolver_ip]
  }
  tags = local.tags
}

resource "azurerm_firewall" "hub" {
  count               = local.secure ? 1 : 0
  name                = "afw-${local.prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub[0].id
  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.subnet["firewall"].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }
  tags       = local.tags
  depends_on = [azurerm_private_dns_resolver_inbound_endpoint.hub]
}

resource "azurerm_firewall_policy_rule_collection_group" "lab" {
  count              = local.secure ? 1 : 0
  name               = "lab-traffic"
  firewall_policy_id = azurerm_firewall_policy.hub[0].id
  priority           = 200
  network_rule_collection {
    name     = "approved-private-flows"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "ops-and-corp-to-iis"
      protocols             = ["TCP"]
      source_addresses      = [local.subnets.operations.prefix, local.subnets.corp.prefix]
      destination_addresses = [local.subnets.app.prefix]
      destination_ports     = ["80"]
    }
  }
  application_rule_collection {
    name     = "private-data-and-platform"
    priority = 300
    action   = "Allow"
    rule {
      name             = "private-storage-and-vault"
      source_addresses = [local.subnets.app.prefix, local.subnets.operations.prefix, local.subnets.corp.prefix]
      destination_fqdns = local.apps ? [
        "${azurerm_storage_account.data[0].name}.blob.core.windows.net",
        "${azurerm_key_vault.data[0].name}.vault.azure.net"
      ] : ["placeholder.invalid"]
      protocols {
        type = "Https"
        port = 443
      }
    }
    rule {
      name                  = "windows-update"
      source_addresses      = [local.subnets.app.prefix, local.subnets.operations.prefix]
      destination_fqdn_tags = ["WindowsUpdate"]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
    }
    rule {
      name             = "monitor-agent-and-extensions"
      source_addresses = [local.subnets.app.prefix, local.subnets.operations.prefix]
      destination_fqdns = [
        "*.monitor.azure.com", "*.ods.opinsights.azure.com", "*.oms.opinsights.azure.com",
        "*.handler.control.monitor.azure.com", "*.ingest.monitor.azure.com",
        "global.prod.microsoftmetrics.com", "*.monitoring.azure.com",
        "*.blob.core.windows.net", "management.azure.com", "login.microsoftonline.com"
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }
    rule {
      name              = "allowed-egress-probe"
      source_addresses  = [local.subnets.app.prefix, local.subnets.operations.prefix]
      destination_fqdns = ["www.microsoft.com"]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_public_ip" "bastion" {
  count               = local.secure ? 1 : 0
  name                = "pip-${local.prefix}-bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_bastion_host" "hub" {
  count               = local.secure ? 1 : 0
  name                = "bas-${local.prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Standard"
  tunneling_enabled   = true
  ip_connect_enabled  = true
  copy_paste_enabled  = true
  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.subnet["bastion"].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
  tags       = local.tags
  depends_on = [azurerm_subnet_network_security_group_association.bastion]
}

resource "azurerm_network_security_group" "workload" {
  for_each            = toset(["app", "data", "operations", "corp"])
  name                = "nsg-${local.prefix}-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

# Keep every workload rule as its own resource. Mixing inline and standalone
# rules on the same NSG causes ownership conflicts and repeated differences.
resource "azurerm_network_security_rule" "workload_deny" {
  for_each                    = azurerm_network_security_group.workload
  name                        = "deny-other-vnet-inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = each.value.name
}

resource "azurerm_network_security_rule" "rdp" {
  for_each                    = toset(["app", "operations", "corp"])
  name                        = "rdp-from-bastion"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = local.subnets.bastion.prefix
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.workload[each.key].name
}

resource "azurerm_network_security_rule" "iis" {
  name                        = "iis-from-ingress-ops-and-corp"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefixes     = [local.subnets.ingress.prefix, local.subnets.operations.prefix, local.subnets.corp.prefix]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.workload["app"].name
}

resource "azurerm_network_security_rule" "private_data" {
  name                        = "https-from-firewall"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = local.subnets.firewall.prefix
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.workload["data"].name
}

resource "azurerm_network_security_rule" "corp_dns" {
  name                        = "dns-from-resolver-and-corp"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefixes     = [local.subnets.dns_out.prefix, local.subnets.corp.prefix]
  destination_address_prefix  = local.corp_dns_ip
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.workload["corp"].name
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  for_each                  = azurerm_network_security_group.workload
  subnet_id                 = azurerm_subnet.subnet[each.key].id
  network_security_group_id = each.value.id
  depends_on = [
    azurerm_network_security_rule.rdp,
    azurerm_network_security_rule.iis,
    azurerm_network_security_rule.private_data,
    azurerm_network_security_rule.corp_dns,
    azurerm_network_security_rule.workload_deny
  ]
}

resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-${local.prefix}-bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "bastion_https" {
  name                        = "operator-https"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.operator_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_platform" {
  for_each = {
    gateway = { source = "GatewayManager", ports = ["443"] }
    health  = { source = "AzureLoadBalancer", ports = ["443"] }
    cluster = { source = "VirtualNetwork", ports = ["8080", "5701"] }
  }
  name                        = "platform-${each.key}"
  priority                    = 200 + index(["gateway", "health", "cluster"], each.key)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = each.value.ports
  source_address_prefix       = each.value.source
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_deny" {
  name                        = "deny-other-https"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.subnet["bastion"].id
  network_security_group_id = azurerm_network_security_group.bastion.id
  depends_on = [
    azurerm_network_security_rule.bastion_https,
    azurerm_network_security_rule.bastion_platform,
    azurerm_network_security_rule.bastion_deny
  ]
}
