locals {
  standard_name       = "${upper(var.system_name)}-RG${lower(var.environment)}"
  resource_group_name = concat(azurerm_resource_group.Rg.*, [null])[0]
}

resource "azurerm_resource_group" "Rg" {
  count    = var.enabled ? 1 : 0
  name     = var.name_override != "" ? var.name_override : local.standard_name
  location = var.location
}