resource "azurerm_public_ip" "ingress" {
  count               = local.apps ? 1 : 0
  name                = "pip-${local.prefix}-ingress"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_web_application_firewall_policy" "ingress" {
  count               = local.apps ? 1 : 0
  name                = "waf-${local.prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  policy_settings {
    enabled            = true
    mode               = "Prevention"
    request_body_check = true
  }
  custom_rules {
    name      = "DeterministicLabBlock"
    priority  = 1
    rule_type = "MatchRule"
    action    = "Block"
    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "X-Lab-Block"
      }
      operator           = "Equal"
      negation_condition = false
      match_values       = ["true"]
    }
  }
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
  tags = local.tags
}

resource "azurerm_application_gateway" "ingress" {
  count               = local.apps ? 1 : 0
  name                = "agw-${local.prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  firewall_policy_id  = azurerm_web_application_firewall_policy.ingress[0].id
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }
  gateway_ip_configuration {
    name      = "ingress-subnet"
    subnet_id = azurerm_subnet.subnet["ingress"].id
  }
  frontend_port {
    name = "https"
    port = 443
  }
  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.ingress[0].id
  }
  ssl_certificate {
    name     = "lab-self-signed"
    data     = try(filebase64(var.certificate_path), null)
    password = var.certificate_password
  }
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"
  }
  http_listener {
    name                           = "public-https"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "https"
    protocol                       = "Https"
    ssl_certificate_name           = "lab-self-signed"
    host_name                      = local.app_host
    require_sni                    = true
  }
  backend_address_pool {
    name         = "private-iis"
    ip_addresses = [for key in local.app_vm_keys : local.vms[key].address]
  }
  backend_http_settings {
    name                  = "iis-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "iis-health"
  }
  probe {
    name                = "iis-health"
    protocol            = "Http"
    host                = local.app_host
    path                = "/health.txt"
    interval            = 30
    timeout             = 10
    unhealthy_threshold = 3
    match {
      status_code = ["200"]
    }
  }
  request_routing_rule {
    name                       = "https-to-private-iis"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "public-https"
    backend_address_pool_name  = "private-iis"
    backend_http_settings_name = "iis-http"
  }
  tags = local.tags
  lifecycle {
    precondition {
      condition     = try(fileexists(var.certificate_path), false) && try(length(var.certificate_password) > 0, false)
      error_message = "applications/hybrid requires an existing local PFX certificate_path and certificate_password. Run New-LabCertificate.ps1 first."
    }
  }
  depends_on = [azurerm_virtual_machine_extension.iis, azurerm_subnet_network_security_group_association.ingress]
}

# Deliberately no route-table association: Application Gateway v2's public
# response/control-plane path must not inherit the workload forced tunnel.
resource "azurerm_network_security_group" "ingress" {
  name                = "nsg-${local.prefix}-ingress"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
  security_rule {
    name                       = "operator-https"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.operator_cidrs
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "gateway-manager"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "platform-load-balancer"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "deny-other-https"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "ingress" {
  subnet_id                 = azurerm_subnet.subnet["ingress"].id
  network_security_group_id = azurerm_network_security_group.ingress.id
}
