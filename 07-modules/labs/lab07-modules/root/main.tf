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
}

# Provider blocks live ONLY in the root module; child modules inherit them.
provider "azurerm" {
  features {}
}

variable "student" {
  type = string
}

variable "location" {
  type    = string
  default = "centralindia"
}

locals {
  tags = { course = "tf-azure-training", owner = var.student, managed_by = "terraform" }

  # One storage account per workload, created with for_each on the module
  storage_accounts = {
    app  = { containers = ["uploads", "exports"], replication = "LRS" }
    logs = { containers = ["diagnostics"], replication = "LRS" }
  }
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.student}-lab07"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../modules/vnet"

  name                = "vnet-${var.student}-lab07"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.30.0.0/16"]
  tags                = local.tags

  subnets = {
    web = {
      address_prefixes = ["10.30.1.0/24"]
      nsg_rules = [
        { name = "allow-https", priority = 100, destination_port_range = "443", source_address_prefix = "Internet" },
      ]
    }
    app = {
      address_prefixes  = ["10.30.2.0/24"]
      service_endpoints = ["Microsoft.Storage"]
      nsg_rules = [
        { name = "allow-web", priority = 100, destination_port_range = "8080", source_address_prefix = "10.30.1.0/24" },
      ]
    }
  }
}

module "storage" {
  source   = "../modules/storage-account"
  for_each = local.storage_accounts

  name                = "st${var.student}${each.key}${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  replication_type    = each.value.replication
  containers          = each.value.containers
  # Module composition: an output of one module feeds another
  allowed_subnet_ids = [module.network.subnet_ids["app"]]
  tags               = local.tags
}

output "subnet_ids" {
  value = module.network.subnet_ids
}

output "storage_endpoints" {
  value = { for k, m in module.storage : k => m.primary_blob_endpoint }
}
