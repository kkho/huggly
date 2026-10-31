# Modules/compute/app_service.tf.scriban
resource "azurerm_linux_web_app" "conferenti-app" {
  name                = "conferenti-app-prod"
  resource_group_name = azurerm_resource_group.conferenti.name
  location            = "norwayeast"
  service_plan_id     = azurerm_service_plan.conferenti-plan.id
  https_only          = true

  site_config {
    always_on             = true
    http2_enabled         = true
    minimum_tls_version   = "1.2"
    ftps_state            = "Disabled"
    health_check_path     = "/health"

    health_check_eviction_time_in_min = 10
    application_stack {
      dotnet_version = "10.0"
    }
  }
  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = "Production"
  }
}
