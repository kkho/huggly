output "azurerm_aks" {
  value = azurerm_kubernetes_cluster.aks
}

output "host" {
  value = azurerm_kubernetes_cluster.aks.kube_config[0].host
}