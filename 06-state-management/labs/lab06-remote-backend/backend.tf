# Partial configuration: the rest comes from backend.hcl
#   terraform init -backend-config=backend.hcl -migrate-state
terraform {
  backend "azurerm" {
    key = "lab06/app.tfstate"
  }
}
