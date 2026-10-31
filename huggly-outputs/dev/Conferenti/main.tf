# Templates/Files/System/main.tf.scriban

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

resource "azurerm_resource_group" "conferenti" {
  name     = "rg-conferenti-dev"
  location = "norwayeast"
}
