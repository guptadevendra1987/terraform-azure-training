# Lab 9.1: one configuration, many workspaces (separate state per workspace).
#   terraform workspace new dev && terraform apply -var="student=dg"
#   terraform workspace new prod && terraform apply -var="student=dg"
terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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
  env = terraform.workspace

  # Per-workspace settings live in code, so a reviewer sees every environment
  settings = {
    default = { location = "centralindia", address_space = "10.90.0.0/16" }
    dev     = { location = "centralindia", address_space = "10.91.0.0/16" }
    prod    = { location = "southindia", address_space = "10.92.0.0/16" }
  }
  cfg = local.settings[local.env]
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.student}-ws-${local.env}"
  location = local.cfg.location
  tags     = { course = "tf-azure-training", owner = var.student, environment = local.env }
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.student}-ws-${local.env}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [local.cfg.address_space]
}

output "workspace" {
  value = terraform.workspace
}
