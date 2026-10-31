# Modules/compute/service_plan.tf.scriban
resource "azurerm_service_plan" "conferenti-plan" {
  name                      = "conferenti-plan-prod"
  resource_group_name       = azurerm_resource_group.conferenti.name
  location                  = "norwayeast"
  os_type                   = "Linux"
  sku_name                  = "B1"

  worker_count              = "1"

}


