terraform {
  backend "azurerm" {
    resource_group_name  = "myResourceGroup"
    storage_account_name = "mystorageaccountcrs1"
    container_name       = "terraform-state"
    key                  = "terraform.tfstate"
  }
}
