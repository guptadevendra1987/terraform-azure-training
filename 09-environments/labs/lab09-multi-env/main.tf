locals {
  name = "${var.student}-app-${var.environment}"
  tags = {
    course      = "tf-azure-training"
    owner       = var.student
    environment = var.environment
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# Reuse the module from Module 07: identical code in every environment, only the inputs differ
module "network" {
  source = "../../../07-modules/labs/lab07-modules/modules/vnet"

  name                = "vnet-${local.name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.address_space]
  tags                = local.tags

  subnets = {
    for name, s in var.subnets : name => {
      address_prefixes = [cidrsubnet(var.address_space, 8, s.netnum)]
    }
  }
}

resource "azurerm_management_lock" "rg" {
  count = var.enable_delete_lock ? 1 : 0

  name       = "lock-cannot-delete"
  scope      = azurerm_resource_group.main.id
  lock_level = "CanNotDelete"
  notes      = "Production resource group. Remove the lock through code review only."
}

output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "subnet_ids" {
  value = module.network.subnet_ids
}
