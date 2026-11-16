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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      # Lab convenience only. In production keep soft-deleted vaults for recovery.
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}

variable "student" {
  type = string
}

variable "location" {
  type    = string
  default = "centralindia"
}

data "azurerm_client_config" "current" {}

locals {
  tags = { course = "tf-azure-training", owner = var.student }
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_resource_group" "sec" {
  name     = "rg-${var.student}-lab10"
  location = var.location
  tags     = local.tags
}

# --- Identities -------------------------------------------------------------

# Entra ID group for the app team; access is granted to groups, never to individuals
resource "azuread_group" "app_readers" {
  display_name     = "sg-${var.student}-lab10-kv-readers"
  security_enabled = true
  owners           = [data.azurerm_client_config.current.object_id]
}

# User-assigned identity exists BEFORE any workload, so access is ready at first boot
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.student}-app"
  location            = azurerm_resource_group.sec.location
  resource_group_name = azurerm_resource_group.sec.name
  tags                = local.tags
}

resource "azuread_group_member" "app_identity" {
  group_object_id  = azuread_group.app_readers.object_id
  member_object_id = azurerm_user_assigned_identity.app.principal_id
}

# --- Key Vault with RBAC authorisation --------------------------------------

resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.student}-lab10-${random_string.suffix.result}"
  location                   = azurerm_resource_group.sec.location
  resource_group_name        = azurerm_resource_group.sec.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false # true in production (cannot be undone!)
  soft_delete_retention_days = 7
  tags                       = local.tags

  network_acls {
    default_action = "Allow" # "Deny" + private endpoint in production
    bypass         = "AzureServices"
  }
}

# The identity running Terraform needs data-plane rights to write secrets
resource "azurerm_role_assignment" "deployer_kv_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "readers_kv_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_group.app_readers.object_id
}

# RBAC is eventually consistent: wait before using the new permissions
resource "time_sleep" "rbac_propagation" {
  depends_on      = [azurerm_role_assignment.deployer_kv_officer]
  create_duration = "60s"
}

# --- Secrets ----------------------------------------------------------------

resource "random_password" "db_admin" {
  length           = 24
  special          = true
  override_special = "!#%*-_=+"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# time_static keeps the expiry stable; timestamp() would change on every plan
resource "time_static" "created" {}

resource "azurerm_key_vault_secret" "db_admin" {
  name            = "sql-admin-password"
  value           = random_password.db_admin.result
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "password"
  expiration_date = timeadd(time_static.created.rfc3339, "8760h") # 1 year

  depends_on = [time_sleep.rbac_propagation] # hidden dependency: data-plane RBAC
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "secret_versionless_id" {
  description = "Reference this from apps: @Microsoft.KeyVault(SecretUri=...)"
  value       = azurerm_key_vault_secret.db_admin.versionless_id
}

output "app_identity_client_id" {
  value = azurerm_user_assigned_identity.app.client_id
}
