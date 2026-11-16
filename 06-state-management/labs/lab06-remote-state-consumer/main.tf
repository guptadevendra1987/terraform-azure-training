# Consumer stack: reads the network stack's outputs from its remote state.
# Prerequisite: the Lab 04 / Lab 05 network stack stored with key "lab06/network.tfstate".
terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    key = "lab06/app-consumer.tfstate"
  }
}

provider "azurerm" {
  features {}
}

variable "student" {
  type = string
}

variable "state_storage_account" {
  type        = string
  description = "Name of the storage account created by bootstrap-backend."
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-${var.student}-tfstate"
    storage_account_name = var.state_storage_account
    container_name       = "tfstate"
    key                  = "lab06/network.tfstate"
    use_azuread_auth     = true
  }
}

resource "azurerm_resource_group" "app" {
  name     = "rg-${var.student}-lab06-app"
  location = "centralindia"
  tags     = { course = "tf-azure-training", owner = var.student }
}

resource "azurerm_network_interface" "app" {
  name                = "nic-${var.student}-app"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.terraform_remote_state.network.outputs.subnet_ids["app"]
    private_ip_address_allocation = "Dynamic"
  }
}

output "nic_private_ip" {
  value = azurerm_network_interface.app.private_ip_address
}
