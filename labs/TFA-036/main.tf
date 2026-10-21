locals {
  tags = merge(var.tags, {
    course = "Terraforming-Azure", lab = "TFA-036", managed_by = "Terraform"
    }
  )
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

data "azurerm_client_config" "current" {
}

resource "azurerm_user_assigned_identity" "github" {
  name                = "id-${var.name_prefix}-github"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "github" {
  for_each = toset([var.github_environment, var.github_plan_environment])

  name                      = "github-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.github.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}/${var.github_repository}:environment:${each.key}"
}

resource "azurerm_role_assignment" "lab_contributor" {
  scope                = azurerm_resource_group.lab.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}
