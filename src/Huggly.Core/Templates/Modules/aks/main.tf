locals {
  aks            = concat(azurerm_kubernetes_cluster.aks.*, [null])
  key_vault_name = "aks-${var.environment}"
}

data "azurerm_subscription" "current" {}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.name}${var.environment}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  dns_prefix          = "aks"
  kubernetes_version  = var.kubernetes_version
  node_resource_group = "${var.resource_group.name}-worker"

  sku_tier                  = var.sku_tier
  automatic_upgrade_channel = "node-image"
  node_os_upgrade_channel   = "NodeImage"

  local_account_disabled              = false
  private_cluster_public_fqdn_enabled = false
  workload_identity_enabled           = true
  oidc_issuer_enabled                 = true
  image_cleaner_interval_hours        = 48

  azure_policy_enabled              = true
  http_application_routing_enabled  = false
  role_based_access_control_enabled = true

  default_node_pool {
    name                         = "nodepool2" # should be changed but it triggers replacement of entire cluster
    temporary_name_for_rotation  = "tmpnodepool2"
    node_count                   = var.system_node_pool.node_count
    vm_size                      = var.system_node_pool.vm_size
    zones                        = var.system_node_pool.zones
    os_disk_type                 = "Ephemeral"
    host_encryption_enabled      = false
    only_critical_addons_enabled = var.system_node_pool.only_critical_addons_enabled
    vnet_subnet_id               = var.vnet_subnet_id
  }

  linux_profile {
    admin_username = "orgadmin"

    ssh_key {
      key_data = var.ssh_public_key
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    # Required for availability zones
    load_balancer_sku = "standard"
    network_policy    = "azure"
    dns_service_ip    = var.dns_service_ip
    service_cidr      = var.service_cidr

    load_balancer_profile {
      managed_outbound_ip_count = 1
      outbound_ports_allocated  = 2048
      idle_timeout_in_minutes   = 30
    }
  }

  dynamic "oms_agent" {
    for_each = var.oms_agent_enabled ? [1] : []

    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = data.azurerm_subscription.current.tenant_id
    admin_group_object_ids = [""] # systmaccess-devops-admin TODO
    azure_rbac_enabled     = false
  }

  windows_profile {
    admin_username = "orgadmin"
    admin_password = random_password.windowsprofile.result
  }

  dynamic "workload_autoscaler_profile" {
    for_each = var.environment == "sandbox" || var.environment == "dev" ? [1] : []

    content {
      vertical_pod_autoscaler_enabled = true
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      upgrade_override, # Error: `upgrade_override` cannot be unset
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user_node_pool" {
  for_each = (
    var.user_node_pools != null ?
    { for name, spec in var.user_node_pools : name => spec if spec != null } :
    {}
  )

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vnet_subnet_id        = var.vnet_subnet_id
  vm_size               = each.value.vm_size

  auto_scaling_enabled = true
  max_count            = each.value.max_count
  min_count            = each.value.min_count
  max_pods             = 250

  node_labels = each.value.node_labels
  node_taints = each.value.node_taints
  tags        = each.value.tags
}

resource "random_password" "windowsprofile" {
  length  = 20
  special = true
}

resource "azurerm_key_vault_secret" "linux_profile_admin_username" {
  name         = "linux-profile-admin-username"
  value        = "orgadmin"
  key_vault_id = var.key_vault_id

  tags = {
    environment = var.environment
  }

}

resource "azurerm_key_vault_secret" "windows_profile_admin_username" {
  name         = "windows-profile-admin-username"
  value        = "orgadmin"
  key_vault_id = var.key_vault_id

  tags = {
    environment = var.environment
  }

}

resource "azurerm_key_vault_secret" "windows_profile_admin_password" {
  name         = "windows-profile-admin-password"
  value        = random_password.windowsprofile.result
  key_vault_id = var.key_vault_id

  tags = {
    environment = var.environment
  }
}

resource "azurerm_monitor_diagnostic_setting" "aks_storage_account" {
  count = var.environment == "prod" ? 1 : 0

  name               = "aks-diagnostic-setting"
  target_resource_id = azurerm_kubernetes_cluster.aks.id
  storage_account_id = azurerm_storage_account.aks[0].id

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }
}

resource "azurerm_storage_account" "aks" {
  count = var.environment == "prod" ? 1 : 0

  name                     = "${var.system_name}aksdiagnostic${var.environment}"
  location                 = var.resource_group.location
  resource_group_name      = var.resource_group.name
  account_tier             = "Standard"
  access_tier              = "Cool"
  account_replication_type = "LRS"

  blob_properties {
    delete_retention_policy {
      days = 365
    }
  }
}

data "tfe_workspace" "system_bootstrap" {
  name         = "system-bootstrap-m-z"
  organization = var.organization
}


resource "tfe_variable" "system_bootstrap_k8s_host" {
  key          = "${var.system_name}_k8s_host_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config[0].host
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_k8s_cluster_ca_certificate" {
  key          = "${var.system_name}_k8s_cluster_ca_certificate_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_k8s_client_certificate" {
  key          = "${var.system_name}_k8s_client_certificate_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_k8s_client_key" {
  key          = "${var.system_name}_k8s_client_key_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap.id
  description  = "Set by aks-terraform. Do not manually modify."
  sensitive    = true
}

resource "tfe_variable" "system_bootstrap_aksservice_subscription_id" {
  key          = "${var.system_name}_subscription_id_${var.environment}"
  value        = data.azurerm_subscription.current.subscription_id
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_aksservice_subscription_name" {
  key          = "${var.system_name}_subscription_name_${var.environment}"
  value        = data.azurerm_subscription.current.display_name
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_aksservice_tenant_id" {
  key          = "${var.system_name}_tenant_id_${var.environment}"
  value        = data.azurerm_subscription.current.tenant_id
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_aksservice_resource_group_id" {
  key          = "${var.system_name}_aks_resource_group_id_${var.environment}"
  value        = var.resource_group.id
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap.id
  description  = "Set by aks-terraform. Do not manually modify."
}

# Add k8s variables to system-bootstrap-a-e
data "tfe_workspace" "system_bootstrap_a_e" {
  name         = "system-bootstrap-a-e"
  organization = var.organization
}


resource "tfe_variable" "system_bootstrap_a_e_k8s_host" {
  key          = "${var.system_name}_k8s_host_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config[0].host
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_a_e.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_a_e_k8s_cluster_ca_certificate" {
  key          = "${var.system_name}_k8s_cluster_ca_certificate_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_a_e.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_a_e_k8s_client_certificate" {
  key          = "${var.system_name}_k8s_client_certificate_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_a_e.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_a_e_k8s_client_key" {
  key          = "${var.system_name}_k8s_client_key_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_a_e.id
  description  = "Set by aks-terraform. Do not manually modify."
  sensitive    = true
}

resource "tfe_variable" "system_bootstrap_a_e_aksservice_subscription_id" {
  key          = "${var.system_name}_subscription_id_${var.environment}"
  value        = data.azurerm_subscription.current.subscription_id
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_a_e.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_a_e_aksservice_subscription_name" {
  key          = "${var.system_name}_subscription_name_${var.environment}"
  value        = data.azurerm_subscription.current.display_name
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_a_e.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_a_e_aksservice_tenant_id" {
  key          = "${var.system_name}_tenant_id_${var.environment}"
  value        = data.azurerm_subscription.current.tenant_id
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_a_e.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_a_e_aksservice_resource_group_id" {
  key          = "${var.system_name}_aks_resource_group_id_${var.environment}"
  value        = var.resource_group.id
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_a_e.id
  description  = "Set by aks-terraform. Do not manually modify."
}

data "tfe_workspace" "system_bootstrap_f_l" {
  name         = "system-bootstrap-f-l"
  organization = var.organization
}

resource "tfe_variable" "system_bootstrap_f_l_k8s_host" {
  key          = "${var.system_name}_k8s_host_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config[0].host
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_f_l.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_f_l_k8s_cluster_ca_certificate" {
  key          = "${var.system_name}_k8s_cluster_ca_certificate_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_f_l.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_f_l_k8s_client_certificate" {
  key          = "${var.system_name}_k8s_client_certificate_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_f_l.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_f_l_k8s_client_key" {
  key          = "${var.system_name}_k8s_client_key_${var.environment}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_f_l.id
  description  = "Set by aks-terraform. Do not manually modify."
  sensitive    = true
}

resource "tfe_variable" "system_bootstrap_f_l_aksservice_subscription_id" {
  key          = "${var.system_name}_subscription_id_${var.environment}"
  value        = data.azurerm_subscription.current.subscription_id
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_f_l.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_f_l_aksservice_subscription_name" {
  key          = "${var.system_name}_subscription_name_${var.environment}"
  value        = data.azurerm_subscription.current.display_name
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_f_l.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_f_l_aksservice_tenant_id" {
  key          = "${var.system_name}_tenant_id_${var.environment}"
  value        = data.azurerm_subscription.current.tenant_id
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_f_l.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "system_bootstrap_f_l_aksservice_resource_group_id" {
  key          = "${var.system_name}_aks_resource_group_id_${var.environment}"
  value        = var.resource_group.id
  category     = "terraform"
  workspace_id = data.tfe_workspace.system_bootstrap_f_l.id
  description  = "Set by aks-terraform. Do not manually modify."
}

# Add k8s variables to vault-configuration
data "tfe_workspace" "vault_configuration" {
  name         = "vault-configuration-${var.environment == "sandbox" ? "dev" : var.environment}"
  organization = var.organization
}

resource "tfe_variable" "vault_configuration_k8s_host" {
  key          = "${var.system_name}_k8s_host${var.environment == "sandbox" ? "_sandbox" : ""}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config[0].host
  category     = "terraform"
  workspace_id = data.tfe_workspace.vault_configuration.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "vault_configuration_k8s_cluster_ca_certificate" {
  key          = "${var.system_name}_k8s_cluster_ca_certificate${var.environment == "sandbox" ? "_sandbox" : ""}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate
  category     = "terraform"
  workspace_id = data.tfe_workspace.vault_configuration.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "vault_configuration_k8s_client_certificate" {
  key          = "${var.system_name}_k8s_client_certificate${var.environment == "sandbox" ? "_sandbox" : ""}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate
  category     = "terraform"
  workspace_id = data.tfe_workspace.vault_configuration.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "vault_configuration_k8s_client_key" {
  key          = "${var.system_name}_k8s_client_key${var.environment == "sandbox" ? "_sandbox" : ""}"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key
  category     = "terraform"
  workspace_id = data.tfe_workspace.vault_configuration.id
  description  = "Set by aks-terraform. Do not manually modify."
  sensitive    = true
}

data "tfe_workspace" "dns" {
  name         = "dns-${var.environment}"
  organization = var.organization
}

resource "tfe_variable" "dns_k8s_host" {
  key          = "${var.system_name}_k8s_host"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config[0].host
  category     = "terraform"
  workspace_id = data.tfe_workspace.dns.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "dns_k8s_cluster_ca_certificate" {
  key          = "${var.system_name}_k8s_cluster_ca_certificate"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate
  category     = "terraform"
  workspace_id = data.tfe_workspace.dns.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "dns_k8s_client_certificate" {
  key          = "${var.system_name}_k8s_client_certificate"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate
  category     = "terraform"
  workspace_id = data.tfe_workspace.dns.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "dns_k8s_client_key" {
  key          = "${var.system_name}_k8s_client_key"
  value        = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key
  category     = "terraform"
  workspace_id = data.tfe_workspace.dns.id
  description  = "Set by aks-terraform. Do not manually modify."
  sensitive    = true
}

resource "tfe_variable" "dns_aksservice_subscription_id" {
  key          = "${var.system_name}_subscription_id"
  value        = data.azurerm_subscription.current.subscription_id
  category     = "terraform"
  workspace_id = data.tfe_workspace.dns.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "dns_aksservice_subscription_name" {
  key          = "${var.system_name}_subscription_name"
  value        = data.azurerm_subscription.current.display_name
  category     = "terraform"
  workspace_id = data.tfe_workspace.dns.id
  description  = "Set by aks-terraform. Do not manually modify."
}

resource "tfe_variable" "dns_aksservice_tenant_id" {
  key          = "${var.system_name}_tenant_id"
  value        = data.azurerm_subscription.current.tenant_id
  category     = "terraform"
  workspace_id = data.tfe_workspace.dns.id
  description  = "Set by aks-terraform. Do not manually modify."
}

