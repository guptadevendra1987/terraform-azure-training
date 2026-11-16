# Bulk import with for_each on import blocks (Terraform >= 1.7).
# Setup: create the "legacy" groups first:
#   for n in web app data; do az group create -n rg-dg-legacy-$n -l centralindia --tags course=tf-azure-training owner=dg; done
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
  type    = string
  default = "dg"
}

data "azurerm_subscription" "current" {}

locals {
  legacy_groups = toset(["web", "app", "data"])
}

import {
  for_each = local.legacy_groups
  to       = azurerm_resource_group.legacy[each.key]
  id       = "${data.azurerm_subscription.current.id}/resourceGroups/rg-${var.student}-legacy-${each.key}"
}

resource "azurerm_resource_group" "legacy" {
  for_each = local.legacy_groups

  name     = "rg-${var.student}-legacy-${each.key}"
  location = "centralindia"
  tags     = { course = "tf-azure-training", owner = var.student }
}
