resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "main" {
  name                = local.storage_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  account_tier        = var.storage.tier
  # Production always gets zone-redundant storage, whatever the input says
  account_replication_type = local.is_production ? "ZRS" : var.storage.replication_type
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = var.storage.retention_days
    }
  }

  # Challenge 1: only restrict the network when IP ranges are supplied
  network_rules {
    default_action = length(var.allowed_ip_ranges) > 0 ? "Deny" : "Allow"
    ip_rules       = [for ip in var.allowed_ip_ranges : trimsuffix(ip, "/32")]
    bypass         = ["AzureServices"]
  }

  tags = local.common_tags
}

# Single container for now; Module 05 turns this into for_each over var.storage.containers
resource "azurerm_storage_container" "first" {
  name                  = var.storage.containers[0]
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}
