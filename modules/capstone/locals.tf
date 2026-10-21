locals {
  stage_index = index(["foundation", "secure", "applications", "hybrid"], var.stage)
  secure      = local.stage_index >= 1
  apps        = local.stage_index >= 2
  hybrid      = local.stage_index >= 3
  prefix      = "${var.name_prefix}-${var.environment}"
  # Deterministic subscription/resource-group salt avoids globally colliding service names.
  suffix = substr(sha256(azurerm_resource_group.lab.id), 0, 8)
  tags   = merge(var.tags, { project = "Terraforming-Azure", lab = "TFA-040", environment = var.environment })

  networks = {
    hub        = var.address_plan.hub
    app        = var.address_plan.app
    data       = var.address_plan.data
    operations = var.address_plan.operations
    onprem     = var.address_plan.onprem
  }
  subnets = {
    firewall   = { network = "hub", name = "AzureFirewallSubnet", prefix = cidrsubnet(var.address_plan.hub, 10, 0) }
    bastion    = { network = "hub", name = "AzureBastionSubnet", prefix = cidrsubnet(var.address_plan.hub, 10, 1) }
    gateway    = { network = "hub", name = "GatewaySubnet", prefix = cidrsubnet(var.address_plan.hub, 11, 4) }
    dns_in     = { network = "hub", name = "snet-dns-inbound", prefix = cidrsubnet(var.address_plan.hub, 12, 16) }
    dns_out    = { network = "hub", name = "snet-dns-outbound", prefix = cidrsubnet(var.address_plan.hub, 12, 17) }
    ingress    = { network = "app", name = "snet-application-gateway", prefix = cidrsubnet(var.address_plan.app, 8, 0) }
    app        = { network = "app", name = "snet-iis", prefix = cidrsubnet(var.address_plan.app, 8, 1) }
    data       = { network = "data", name = "snet-private-endpoints", prefix = cidrsubnet(var.address_plan.data, 8, 0) }
    operations = { network = "operations", name = "snet-operations", prefix = cidrsubnet(var.address_plan.operations, 8, 0) }
    corp       = { network = "onprem", name = "snet-corp", prefix = cidrsubnet(var.address_plan.onprem, 8, 1) }
    remote_gw  = { network = "onprem", name = "GatewaySubnet", prefix = cidrsubnet(var.address_plan.onprem, 11, 2047) }
  }
  resolver_ip = cidrhost(local.subnets.dns_in.prefix, 4)
  corp_dns_ip = cidrhost(local.subnets.corp.prefix, 4)

  app_vm_keys = ["iis01", "iis02"]
  vms = merge(local.apps ? {
    iis01 = { subnet = "app", address = cidrhost(local.subnets.app.prefix, 4), size = "Standard_B2s" }
    iis02 = { subnet = "app", address = cidrhost(local.subnets.app.prefix, 5), size = "Standard_B2s" }
    ops01 = { subnet = "operations", address = cidrhost(local.subnets.operations.prefix, 4), size = "Standard_B2s" }
    } : {}, local.hybrid ? {
    corp01 = { subnet = "corp", address = local.corp_dns_ip, size = "Standard_B2s" }
  } : {})

  private_zones = {
    blob  = "privatelink.blob.core.windows.net"
    vault = "privatelink.vaultcore.azure.net"
    azure = "azure.terraforming-azure.test"
  }
  app_host = "app.terraforming-azure.test"
}
