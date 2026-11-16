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
  # Shared keys are disabled on the storage account, so the provider must use Entra ID for data-plane calls
  storage_use_azuread = true
}

variable "student" {
  type = string
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "environment" {
  type    = string
  default = "dev"
}

locals {
  name = "${var.student}-web-${var.environment}"
  tags = { course = "tf-azure-training", owner = var.student, environment = var.environment }

  # Environment-driven sizing in one place
  sku = {
    dev  = "B1"
    prod = "P0v3"
  }
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "app" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# --- Observability ----------------------------------------------------------

resource "azurerm_log_analytics_workspace" "app" {
  name                = "log-${local.name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "app" {
  name                = "appi-${local.name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  workspace_id        = azurerm_log_analytics_workspace.app.id
  application_type    = "web"
  tags                = local.tags
}

# --- Storage the app reads with its managed identity (no keys) --------------

resource "azurerm_storage_account" "app" {
  name                            = "st${var.student}web${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.app.name
  location                        = azurerm_resource_group.app.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  tags                            = local.tags
}

resource "azurerm_storage_container" "content" {
  name                  = "content"
  storage_account_id    = azurerm_storage_account.app.id
  container_access_type = "private"
}

# --- App Service ------------------------------------------------------------

resource "azurerm_service_plan" "app" {
  name                = "asp-${local.name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  os_type             = "Linux"
  sku_name            = lookup(local.sku, var.environment, "B1")
  tags                = local.tags
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-${local.name}-${random_string.suffix.result}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  service_plan_id     = azurerm_service_plan.app.id
  https_only          = true
  tags                = local.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on           = var.environment == "prod"
    ftps_state          = "Disabled"
    minimum_tls_version = "1.2"
    health_check_path   = "/"

    health_check_eviction_time_in_min = 5

    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.app.connection_string
    STORAGE_BLOB_ENDPOINT                 = azurerm_storage_account.app.primary_blob_endpoint
    STORAGE_CONTAINER                     = azurerm_storage_container.content.name
    ENVIRONMENT                           = var.environment
  }
}

# Grant the web app's identity read access to blobs: identity-based access, no secrets
resource "azurerm_role_assignment" "app_blob_reader" {
  scope                = azurerm_storage_account.app.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# Send platform logs to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "app" {
  name                       = "diag-to-law"
  target_resource_id         = azurerm_linux_web_app.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.app.id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

output "app_url" {
  value = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "app_principal_id" {
  value = azurerm_linux_web_app.app.identity[0].principal_id
}
