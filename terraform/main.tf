# Resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Container registry
resource "azurerm_container_registry" "acr" {
  name                = var.container_registry_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Cosmos DB account
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = var.cosmos_account_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }
}

# Cosmos DB SQL database
resource "azurerm_cosmosdb_sql_database" "db" {
  name                = var.cosmos_db_name
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

# Cosmos DB container
resource "azurerm_cosmosdb_sql_container" "container" {
  name                 = var.cosmos_db_container_name
  resource_group_name  = azurerm_resource_group.main.name
  account_name         = azurerm_cosmosdb_account.cosmos.name
  database_name        = azurerm_cosmosdb_sql_database.db.name
  partition_key_paths  = ["/id"]
}

# AKS cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.aks_dns_prefix

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = 1
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  kubernetes_version = "1.29.2"
}

# Allow AKS to pull from ACR
data "azurerm_container_registry" "acr" {
  name                = azurerm_container_registry.acr.name
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = data.azurerm_container_registry.acr.id
}

# Create Key Vault
resource "azurerm_key_vault" "key_vault_main" {
  name                        = var.key_vault_name
  resource_group_name         = azurerm_resource_group.main.name
  location                    = var.location
  sku_name                    = "standard"
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 30
}

# # Create Key Vault secret
# resource "azurerm_key_vault_secret" "cosmos_key_secret" {
#   name         = "cosmos-key"
#   value        = azurerm_cosmosdb_account.cosmos.primary_key
#   key_vault_id = azurerm_key_vault.key_vault_main.id
# }