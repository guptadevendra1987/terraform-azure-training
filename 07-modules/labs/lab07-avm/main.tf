# Lab 7.3: consume an Azure Verified Module (AVM) from the public registry.
terraform {
  required_version = ">= 1.12" # the AVM module relies on short-circuit || in validations (Terraform 1.12+)

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

variable "student" {
  type = string
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.student}-lab07-avm"
  location = "centralindia"
  tags     = { course = "tf-azure-training", owner = var.student }
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-${var.student}-avm-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.23"

  name          = "vnet-${var.student}-avm"
  location      = azurerm_resource_group.main.location
  parent_id     = azurerm_resource_group.main.id
  address_space = ["10.40.0.0/16"]
  tags          = azurerm_resource_group.main.tags

  subnets = {
    web = {
      name             = "snet-web"
      address_prefixes = ["10.40.1.0/24"]
      network_security_group = {
        id = azurerm_network_security_group.web.id
      }
    }
    app = {
      name             = "snet-app"
      address_prefixes = ["10.40.2.0/24"]
    }
  }

  enable_telemetry = false
}

output "vnet_id" {
  value = module.vnet.resource_id
}

output "subnet_ids" {
  value = { for k, s in module.vnet.subnets : k => s.resource_id }
}
