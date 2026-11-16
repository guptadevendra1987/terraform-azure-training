terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Partial configuration: terraform init -backend-config=env/<env>.backend.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  storage_use_azuread = true # the workload storage account has shared keys disabled
}
