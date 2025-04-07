output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.cosmos.endpoint
}

output "cosmos_key" {
  value     = azurerm_cosmosdb_account.cosmos.primary_key
  sensitive = true
}

output "cosmos_database" {
  value = azurerm_cosmosdb_sql_database.db.name
}

output "cosmos_container" {
  value = azurerm_cosmosdb_sql_container.container.name
}


output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}
