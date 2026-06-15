variable "name" {
  default = "(Required) The name of the Managed Kubernetes Cluster to create. Changing this forces a new resource to be created."
}

variable "organization" {
  description = "(Required) The name of the Terraform Cloud organization where the workspace is located."
}

variable "environment" {}

variable "resource_group" {
  description = " (Required) Specifies the Resource Group where the Managed Kubernetes Cluster should exist. Changing this forces a new resource to be created."
}

variable "system_name" {
  description = "Required. The name for the system. For example, mmm or idgen."
  # If no default is set, the variable is required.
}

variable "tags" {
  description = "A mapping of tags to assign to the resource."
  type        = map(string)
  default     = {}
}

variable "kubernetes_version" {}

variable "system_node_pool" {
  description = "The object to configure the default system node pool."
  type = object({
    node_count                   = number
    vm_size                      = string
    zones                        = list(string)
    only_critical_addons_enabled = optional(bool, true)
  })
}

variable "user_node_pools" {
  description = "The object to configure user node pools."
  type = map(
    object({
      vm_size     = string
      zones       = optional(list(string), [])
      min_count   = number
      max_count   = number
      node_taints = optional(list(string))
      node_labels = optional(map(any))
      tags        = optional(map(any))
    })
  )
  default  = null
  nullable = true
}


variable "vnet_subnet_id" {
  description = "(Required) The ID of a Subnet where the Kubernetes Node Pool should exist. Changing this forces a new resource to be created."
}

variable "dns_service_ip" {
  description = "IP address within the Kubernetes service address range that will be used by cluster service discovery (kube-dns). This is required when network_plugin is set to azure. Changing this forces a new resource to be created."
}

variable "docker_bridge_cidr" {
  description = "(Optional) IP address (in CIDR notation) used as the Docker bridge IP address on nodes. This is required when network_plugin is set to azure. Changing this forces a new resource to be created."
}

variable "service_cidr" {
  description = "(Optional) The Network Range used by the Kubernetes service. This is required when network_plugin is set to azure. Changing this forces a new resource to be created."
}

variable "oms_agent_enabled" {
  description = "(Required) Is the OMS Agent Enabled?"
}

variable "log_analytics_workspace_id" {
  description = "(Optional) The ID of the Log Analytics Workspace which the OMS Agent should send data to. Must be present if enabled is true."
}

variable "log_analytics_workspace_name" {
  description = "(Optional) The name of the Log Analytics Workspace which the OMS Agent should send data to. Must be present if enabled is true."
}

variable "ssh_public_key" {}

variable "key_vault_id" {}

variable "sku_tier" {}
