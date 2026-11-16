# AFTER: the same infrastructure, migrated to azurerm 5.x. Every change is marked "# v5:".
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0" # v5: major version bump
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "app" {
  name     = "rg-dg-upgrade"
  location = "centralindia"
}

resource "azurerm_virtual_network" "app" {
  name                = "vnet-dg-upgrade"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  address_space       = ["10.90.0.0/16"]
}

resource "azurerm_subnet" "data" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.90.1.0/24"]

  # v5: the service_endpoints list became repeatable service_endpoint blocks
  dynamic "service_endpoint" {
    for_each = toset(["Microsoft.Storage", "Microsoft.Sql"])
    content {
      service = service_endpoint.value
    }
  }
}

resource "azurerm_storage_account" "app" {
  name                     = "stdgupgrade0001"
  resource_group_name      = azurerm_resource_group.app.name
  location                 = azurerm_resource_group.app.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  public_network_access    = "Disabled" # v5: replaces the deprecated boolean public_network_access_enabled
}

resource "azurerm_storage_container" "web" {
  name               = "web"
  storage_account_id = azurerm_storage_account.app.id
}

resource "azurerm_storage_blob" "index" {
  name                 = "index.html"
  storage_container_id = azurerm_storage_container.web.id # v5: one ID instead of account + container names
  type                 = "Block"
  source_content       = "<h1>hello</h1>"
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.app.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "app" {
  name                = "link-app"
  private_dns_zone_id = azurerm_private_dns_zone.blob.id # v5: zone ID replaces resource_group_name + zone name
  virtual_network_id  = azurerm_virtual_network.app.id
}
