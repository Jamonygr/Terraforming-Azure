locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-031", managed_by = "Terraform"
    }
  )
  suffix = substr(sha256("${var.subscription_id}:${var.name_prefix}:${var.location}"), 0, 8)
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "azure" {
  name                = "vnet-${var.name_prefix}-azure"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.31.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "azure_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.31.0.0/27"]
}

resource "azurerm_subnet" "azure_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.31.2.0/24"]
}

resource "azurerm_virtual_network" "onprem" {
  name                = "vnet-${var.name_prefix}-onprem"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.131.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "onprem_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.131.0.0/27"]
}

resource "azurerm_subnet" "onprem_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.131.2.0/24"]
}

resource "azurerm_public_ip" "gateway" {
  for_each            = toset(["azure", "onprem"])
  name                = "pip-${var.name_prefix}-${each.key}-vpn"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway" "lab" {
  for_each = {
    azure = azurerm_subnet.azure_gateway.id, onprem = azurerm_subnet.onprem_gateway.id
  }

  name                = "vpngw-${var.name_prefix}-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  bgp_enabled         = false
  sku                 = "VpnGw1AZ"
  ip_configuration {
    name                          = "primary"
    public_ip_address_id          = azurerm_public_ip.gateway[each.key].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = each.value
  }

  tags = local.tags
}

resource "azurerm_virtual_network_gateway_connection" "tunnel" {
  for_each = {
    azure = "onprem", onprem = "azure"
  }

  name                            = "vpn-${var.name_prefix}-${each.key}-to-${each.value}"
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.lab[each.key].id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.lab[each.value].id
  shared_key                      = var.vpn_shared_key
  tags                            = local.tags
}

resource "azurerm_subnet" "resolver" {
  name                 = "snet-dns-inbound"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.31.1.0/28"]
  delegation {
    name = "resolver"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_resolver" "lab" {
  name                = "dnspr-${var.name_prefix}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  virtual_network_id  = azurerm_virtual_network.azure.id
  tags                = local.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "lab" {
  name                    = "inbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.lab.id
  location                = azurerm_resource_group.lab.location
  ip_configurations {
    private_ip_allocation_method = "Static"
    private_ip_address           = "10.31.1.4"
    subnet_id                    = azurerm_subnet.resolver.id
  }

  tags = local.tags
}

resource "azurerm_storage_account" "lab" {
  name                            = "st${replace(var.name_prefix, "-", "")}${local.suffix}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  tags                            = local.tags
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "blob-to-azure"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.azure.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${var.name_prefix}-blob"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.azure_workload.id
  private_service_connection {
    name                           = "blob"
    private_connection_resource_id = azurerm_storage_account.lab.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = local.tags
}

module "dns" {
  depends_on          = [azurerm_subnet_nat_gateway_association.probe, azurerm_nat_gateway_public_ip_association.probe]
  source              = "../../modules/patterns/windows-vm"
  name                = "${var.name_prefix}-dns"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.onprem_workload.id
  admin_password      = var.admin_password
  bootstrap_command   = "Install-WindowsFeature DNS -IncludeManagementTools; if (-not (Get-DnsServerZone -Name 'corp.tfa.internal' -ErrorAction SilentlyContinue)) { Add-DnsServerPrimaryZone -Name 'corp.tfa.internal' -ZoneFile 'corp.tfa.internal.dns' }; if (-not (Get-DnsServerResourceRecord -ZoneName 'corp.tfa.internal' -Name 'files' -ErrorAction SilentlyContinue)) { Add-DnsServerResourceRecordA -ZoneName 'corp.tfa.internal' -Name 'files' -IPv4Address '10.131.2.4' }; foreach ($zone in @('blob.core.windows.net','privatelink.blob.core.windows.net')) { if (-not (Get-DnsServerZone -Name $zone -ErrorAction SilentlyContinue)) { Add-DnsServerConditionalForwarderZone -Name $zone -MasterServers 10.31.1.4 } }; if (-not (Get-NetFirewallRule -DisplayName 'TFA corporate DNS' -ErrorAction SilentlyContinue)) { New-NetFirewallRule -DisplayName 'TFA corporate DNS' -Direction Inbound -Action Allow -Protocol UDP -LocalPort 53 -RemoteAddress 10.31.1.16/28,10.131.0.0/16; New-NetFirewallRule -DisplayName 'TFA corporate DNS TCP' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 53 -RemoteAddress 10.31.1.16/28,10.131.0.0/16 }"
  private_ip_address  = "10.131.2.4"
  tags                = local.tags
}

resource "azurerm_network_security_group" "dns" {
  name                = "nsg-${var.name_prefix}-dns"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  security_rule {
    name                       = "allow-dns-within-simulated-site"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "10.131.0.0/16"
    destination_address_prefix = "10.131.2.4"
  }

  security_rule {
    name                       = "allow-resolver-outbound-dns"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "10.31.1.16/28"
    destination_address_prefix = "10.131.2.4"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "dns" {
  subnet_id                 = azurerm_subnet.onprem_workload.id
  network_security_group_id = azurerm_network_security_group.dns.id
}
