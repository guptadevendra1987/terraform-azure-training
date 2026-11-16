# Lab 2.3: one configuration, several providers (exam objective 2c).
#   - azurerm (default)      → primary region
#   - azurerm (alias "dr")   → disaster-recovery region (could also be ANOTHER SUBSCRIPTION)
#   - azuread                → Entra ID (a different API: Microsoft Graph)
#   - random                 → a utility provider with no API at all
terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Default provider configuration: used by any azurerm resource without a "provider" argument
provider "azurerm" {
  features {}
}

# Second configuration of the SAME provider, selected with  provider = azurerm.dr
provider "azurerm" {
  alias = "dr"
  features {}
  # In production DR often lives in a separate subscription:
  # subscription_id = var.dr_subscription_id
}

provider "azuread" {}

variable "student" {
  type = string
}

variable "primary_location" {
  type    = string
  default = "centralindia"
}

variable "dr_location" {
  type    = string
  default = "southindia"
}

# azuread data source: who is running Terraform?
data "azuread_client_config" "current" {}

data "azuread_user" "me" {
  object_id = data.azuread_client_config.current.object_id
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  tags = {
    course     = "tf-azure-training"
    owner      = var.student
    created_by = data.azuread_user.me.user_principal_name
  }
}

# --- Primary region (default provider) ---------------------------------------

resource "azurerm_resource_group" "primary" {
  name     = "rg-${var.student}-app-primary"
  location = var.primary_location
  tags     = local.tags
}

resource "azurerm_storage_account" "primary" {
  name                     = "st${var.student}pri${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.primary.name
  location                 = azurerm_resource_group.primary.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.tags
}

# --- DR region (aliased provider) ----------------------------------------------

resource "azurerm_resource_group" "dr" {
  provider = azurerm.dr # ← the only difference

  name     = "rg-${var.student}-app-dr"
  location = var.dr_location
  tags     = local.tags
}

resource "azurerm_storage_account" "dr" {
  provider = azurerm.dr

  name                     = "st${var.student}dr${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.dr.name
  location                 = azurerm_resource_group.dr.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.tags
}

# Cross-provider reference: an azurerm resource reads a value from an azuread data source
resource "azurerm_role_assignment" "me_reader_dr" {
  provider = azurerm.dr

  scope                = azurerm_resource_group.dr.id
  role_definition_name = "Reader"
  principal_id         = data.azuread_client_config.current.object_id
}

output "primary_storage" {
  value = azurerm_storage_account.primary.primary_blob_endpoint
}

output "dr_storage" {
  value = azurerm_storage_account.dr.primary_blob_endpoint
}

output "deployed_by" {
  value = data.azuread_user.me.user_principal_name
}
