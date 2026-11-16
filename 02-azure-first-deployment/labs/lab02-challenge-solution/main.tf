# Lab 2.1 + challenge solution: logs container, lifecycle policy and blob upload.

resource "azurerm_resource_group" "main" {
  name     = "rg-dg-lab02"
  location = "centralindia"

  tags = {
    course = "tf-azure-training"
    owner  = "dg"
  }
}

# Storage account names must be globally unique: 3-24 lowercase letters and digits
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "main" {
  name                     = "stdglab02${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# --- Challenge solution (section 6 of the Module 02 README) ---------------

resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "main" {
  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "delete-old-logs"
    enabled = true
    filters {
      prefix_match = ["logs/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }
}

resource "azurerm_storage_blob" "index" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.main.name
  storage_container_name = azurerm_storage_container.data.name
  type                   = "Block"
  source                 = "${path.module}/index.html"
  content_md5            = filemd5("${path.module}/index.html")
  content_type           = "text/html"
}
