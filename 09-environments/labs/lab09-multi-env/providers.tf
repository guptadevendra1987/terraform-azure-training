terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Partial config; the key and account come from env/<env>/backend.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
