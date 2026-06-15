locals {
  standard_name = "${var.keyvault_name}-${var.environment}"
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "secrets_vault" {
  name                            = var.name_override != "" ? var.name_override : local.standard_name
  location                        = var.resource_group.location
  resource_group_name             = var.resource_group.name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = "standard"
  enabled_for_template_deployment = true
}

resource "azurerm_key_vault_access_policy" "terraform_user_current" {
  key_vault_id = azurerm_key_vault.secrets-vault.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get",
    "List",
    "Create",
    "Delete",
  ]

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
  ]
}

resource "azurerm_key_vault_access_policy" "tech_staff_core_group" {
  key_vault_id = azurerm_key_vault.secrets-vault.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = var.admin_group_id

  certificate_permissions = [
    "Get",
    "List",
  ]

  key_permissions = [
    "Get",
    "List",
    "Create",
    "Delete",
  ]

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
  ]
}

