# Helper module for the integration test: resource group + random suffix.
terraform {
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

variable "student" {
  type = string
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "test" {
  name     = "rg-${var.student}-tftest-${random_string.suffix.result}"
  location = "centralindia"
  tags     = { course = "tf-azure-training", owner = var.student, purpose = "terraform-test" }
}

output "resource_group_name" {
  value = azurerm_resource_group.test.name
}

output "location" {
  value = azurerm_resource_group.test.location
}

output "suffix" {
  value = random_string.suffix.result
}
