variable "name" {
  default = "(Required) Specifies the name of the Container Registry. Changing this forces a new resource to be created."
}

variable "environment" {}

variable "resource_group" {
  description = " (Required) Specifies the Resource Group where the Managed Kubernetes Cluster should exist. Changing this forces a new resource to be created."
}

variable "name_override" {
  description = "Set this to force a name of the resource. Should normally not be used. "
  default     = ""
}

variable "system_name" {
  description = "Required. The name for the system. For example, mmm or idgen."
  # If no default is set, the variable is required.
}

variable "admin_enabled" {
  description = "(Optional) Specifies whether the admin user is enabled."
  default     = true
}

variable "sku" {
  description = " (Optional) The SKU name of the container registry. Possible values are Basic, Standard and Premium."
}

variable "georeplication_locations" {
  description = "(Optional) A list of Azure locations where the container registry should be geo-replicated."
  type        = list(string)
  default     = ["West Europe", "North Europe"]
}

variable "tags" {
  description = "A mapping of tags to assign to the resource."
  type        = map(string)
  default     = {}
}

variable "enabled" {
  default = true
}

variable "key_vault_id" {

}
