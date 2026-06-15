variable "environment" {
}

variable "keyvault_name" {
}
variable "resource_group" {
}

variable "sp_terraform_objectId" {
  default = "e2172657-2ad5-417b-ad7c-7c06ef3a9948"
}

variable "admin_group_id" {}

variable "name_override" {
  description = "Set this to force a name of the resource. Should normally not be used. "
  default     = ""
}

# This variable should be set to the object id of the project's developers group in Azure AD. I.e. group id of AZURE-NETT-EMIF-DEVELOPERS
