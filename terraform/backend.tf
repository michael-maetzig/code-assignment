terraform {
  backend "azurerm" {
    resource_group_name  = "coding-assignment-rg-0"
    storage_account_name = "codingassterraformstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
