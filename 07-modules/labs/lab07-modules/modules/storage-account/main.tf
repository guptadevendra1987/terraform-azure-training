terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Secure-by-default storage account: TLS 1.2, no public blobs, versioning, soft delete.
resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  min_tls_version          = "TLS1_2"

  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = var.shared_access_key_enabled

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = var.soft_delete_days
    }
    container_delete_retention_policy {
      days = var.soft_delete_days
    }
  }

  network_rules {
    default_action             = length(var.allowed_subnet_ids) + length(var.allowed_ip_ranges) > 0 ? "Deny" : "Allow"
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.allowed_ip_ranges
    bypass                     = ["AzureServices"]
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
      error_message = "Storage account name must be 3-24 lowercase letters/digits."
    }
  }
}

resource "azurerm_storage_container" "this" {
  for_each = toset(var.containers)

  name                  = each.key
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
