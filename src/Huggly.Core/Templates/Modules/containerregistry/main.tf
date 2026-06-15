locals {
  resource_group_name = "${upper(var.system_name)}-RG-${upper(var.environment)}"
  key_vault_name      = "aks-${var.environment}"
  acr                 = concat(azurerm_container_registry_acr.*, [null])[0]
}

resource "azurerm_container_registry" "acr" {
  count = var.enabled ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled
}

resource "azurerm_key_vault_secret" "acr_id" {
  count = var.enabled ? 1 : 0

  name         = "acr-id"
  value        = azurerm_container_registry.acr[0].id
  key_vault_id = var.key_vault_id

  tags = {
    environment = var.environment
  }
}

resource "azurerm_key_vault_secret" "acr_admin_username" {
  count = var.enabled ? 1 : 0

  name         = "acr-admin-username"
  value        = azurerm_container_registry.acr[0].admin_username
  key_vault_id = var.key_vault_id

  tags = {
    environment = var.environment
  }
}

resource "azurerm_key_vault_secret" "acr_admin_password" {
  count = var.enabled ? 1 : 0

  name         = "acr-admin-password"
  value        = azurerm_container_registry.acr[0].admin_password
  key_vault_id = var.key_vault_id

  tags = {
    environment = var.environment
  }
}

resource "azurerm_key_vault_secret" "acr_login_server" {
  count = var.enabled ? 1 : 0

  name         = "acr-login-server"
  value        = azurerm_container_registry.acr[0].login_server
  key_vault_id = var.key_vault_id

  tags = {
    environment = var.environment
  }
}

data "tfe_workspace" "coreservice_dev" {
  name         = "core-dev"
  organization = "{{ CompanyName }}"
}

resource "tfe_variable" "coreservice_dev_acr-id" {
  count = var.enabled ? 1 : 0

  key          = "acr_resource-id"
  value        = azurerm_container_registry.acr[0].id
  category     = "terraform"
  sensitive    = false
  workspace_id = data.tfe_workspace.coreservice_dev.id
  description  = "Set by coreservice-terraform. Do not manually modify or delete."
}

data "tfe_workspace" "coreservice_test" {
  name         = "core-test"
  organization = "{{ CompanyName }}"
}

data "tfe_variable" "coreservice_test_acr_id" {
  count = var.enabled ? 1 : 0

  key          = "acr_resource_id"
  value        = azurerm_container_registry.acr[0].id
  category     = "terraform"
  sensitive    = "false"
  workspace_id = data.tfe_workspace.coreservice_test.id
  description  = "Set by coreservice-terraform. Do not manually modify or delete."
}

data "tfe_workspace" "system_bootstrap" {
  name         = "system-bootstrap-m-z"
  organization = "{{ CompanyName }}"
}

resource "tfe_variable" "system_bootstrap_acr_id" {
  count = var.enabled ? 1 : 0

  key          = "acr_resource_id_${var.environment}"
  value        = azurerm_container_registry.acr[0].id
  category     = "terraform"
  sensitive    = "false"
  workspace_id = data.tfe_workspace.system_bootstrap.id
  description  = "Set by coreservice-terraform. Do not manually modify or delete."
}

data "tfe_variable" "system_bootstrap_f_l_acr_id" {
  count = var.enabled ? 1 : 0

  key          = "acr_resource_id_${var.environment}"
  value        = azurerm_container_registry.acr[0].id
  category     = "terraform"
  sensitive    = "false"
  workspace_id = data.tfe_workspace.system_bootstrap_f_l.id
  description  = "Set by coreservice-terraform. Do not manually modify or delete."
}

resource "azurerm_container_registry_task" "clean" {
  count = var.enabled ? 1 : 0

  name                  = "cleanAcrTaskAllImages"
  container_registry_id = azurerm_container_registry.acr[0].id

  platform {
    os = "linux"
  }
  encoded_step {
    task_content = <<EOF
version: v1.1.0
steps:
  - cmd: acr purge --filter "core.*:.*" --filter "monitoring.*:.*" --filter "onetime.*:.*" --ago 60d --keep 5 --untagged
    disableWorkingDirectoryOverride: true
    timeout: 10800
EOF
  }

  agent_setting {
    cpu = 2
  }

  base_image_trigger {
    name                        = "defaultBaseimageTriggerName"
    type                        = "Runtime"
    enabled                     = true
    update_trigger_payload_type = "Default"
  }
  timer_trigger {
    name     = "DailyTrigger"
    schedule = "0 10 * * *" # At 10:00.
    enabled  = true
  }

  lifecycle {
    ignore_changes = [
      container_registry_id
    ]
  }
}

# Create a scope map for the policy-controller to have read-only access to the ACR.
resource "azurerm_container_registry_scope_map" "policy-controller" {
  count = var.enabled ? 1 : 0

  name                    = "policy-controller-read-only-all-repositories"
  container_registry_name = azurerm_container_registry.acr[0].name
  resource_group_name     = azurerm_container_registry.acr[0].resource_group_name
  description             = "Gives policy-controller read only access to all repositories"
  actions = [
    "repositories/*/content/read",
    "repositories/*/metadata/read",
  ]
}

resource "azurerm_container_registry_token" "policy-controller" {
  count = var.enabled ? 1 : 0

  name                    = azurerm_container_registry_scope_map.policy-controller[0].name
  container_registry_name = azurerm_container_registry.acr[0].name
  resource_group_name     = azurerm_container_registry.acr[0].resource_group_name
  scope_map_id            = azurerm_container_registry_scope_map.policy-controller[0].id
}

resource "azurerm_container_registry_token_password" "policy-controller" {
  count = var.enabled ? 1 : 0

  container_registry_token_id = azurerm_container_registry_token.policy-controller[0].id

  password1 {}
}

