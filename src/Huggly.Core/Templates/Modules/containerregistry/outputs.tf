output "azurerm_container_registry" {
  value = local.acr
}

output "policy_controller_token" {
  value = try(azurerm_container_registry_token_password.policy-controller[0].password1[0].value, "")
}
