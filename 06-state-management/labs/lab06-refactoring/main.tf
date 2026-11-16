# Final state of Lab 6.2 after all refactoring steps.
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

provider "azurerm" {
  features {}
}

variable "student" {
  type = string
}

locals {
  tags = { course = "tf-azure-training", owner = var.student }
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.student}-lab06"
  location = "centralindia"
  tags     = local.tags
}

# Step 1: renamed from "main" to "app"
resource "azurerm_storage_account" "app" {
  name                     = "st${var.student}lab06${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.tags
}

moved {
  from = azurerm_storage_account.main
  to   = azurerm_storage_account.app
}

# Step 2: single container converted to for_each
resource "azurerm_storage_container" "this" {
  for_each              = toset(["data"])
  name                  = each.key
  storage_account_id    = azurerm_storage_account.app.id
  container_access_type = "private"
}

moved {
  from = azurerm_storage_container.first
  to   = azurerm_storage_container.this["data"]
}

# Step 3: the separate "logs" container was handed over to another team.
# removed blocks only accept whole resources, never instance keys like this["logs"].
removed {
  from = azurerm_storage_container.logs

  lifecycle {
    destroy = false
  }
}
