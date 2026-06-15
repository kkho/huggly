# Modules/compute/app_service.tf.scriban
resource "azurerm_linux_web_app" "conferenti-app" {
  name                = "conferenti-app-dev"
  resource_group_name = azurerm_resource_group.conferenti.name
  location            = "norwayeast"
  service_plan_id     = azurerm_service_plan.my-plan.id
  https_only          = true

  site_config {
    always_on             = true
    http2_enabled         = true
    minimum_tls_version   = "1.2"
    ftps_state            = "Disabled"
    health_check_path     = "/health"
    application_stack {
      dotnet_version = "10"
    }
  }
  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = "Development"
  }
}
