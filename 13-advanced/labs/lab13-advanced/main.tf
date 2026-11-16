# Module 13: AzAPI, ephemeral values + write-only arguments, provider functions, bulk import.
terraform {
  required_version = ">= 1.11" # write-only arguments need 1.11

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7" # ephemeral random_password needs 3.7+
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "azapi" {}

variable "student" {
  type = string
}

variable "secret_version" {
  type        = number
  description = "Bump to rotate the write-only secret."
  default     = 1
}

data "azurerm_client_config" "current" {}

locals {
  tags = { course = "tf-azure-training", owner = var.student }
}

# --- 1. AzAPI: any ARM resource type / API version -------------------------

resource "azapi_resource" "rg" {
  type     = "Microsoft.Resources/resourceGroups@2024-03-01"
  name     = "rg-${var.student}-lab13"
  location = "centralindia"
  tags     = local.tags
}

resource "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-${var.student}-lab13"
  parent_id = azapi_resource.rg.id
  location  = azapi_resource.rg.location
  tags      = local.tags

  # The body is the ARM REST API payload, as HCL (no jsonencode needed in azapi v2)
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.80.0.0/16"] }
      subnets = [
        { name = "snet-app", properties = { addressPrefix = "10.80.1.0/24" } }
      ]
    }
  }

  # Export only what you need from the API response
  response_export_values = ["properties.subnets", "properties.resourceGuid"]
}

# azurerm and azapi interoperate: azurerm resources can live in an azapi-created RG
resource "azurerm_key_vault" "lab" {
  name                       = "kv-${var.student}-l13-${substr(md5(azapi_resource.rg.id), 0, 5)}"
  location                   = azapi_resource.rg.location
  resource_group_name        = azapi_resource.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  tags                       = local.tags
}

resource "azurerm_role_assignment" "me_kv" {
  scope                = azurerm_key_vault.lab.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# azapi_update_resource patches properties of a resource managed elsewhere (or not supported by azurerm)
resource "azapi_update_resource" "vnet_flow_timeout" {
  type        = "Microsoft.Network/virtualNetworks@2024-05-01"
  resource_id = azapi_resource.vnet.id

  body = {
    properties = {
      flowTimeoutInMinutes = 10
    }
  }
}

# --- 2. Ephemeral values + write-only arguments: the secret never touches state ---

ephemeral "random_password" "db" {
  length  = 24
  special = true
}

resource "azurerm_key_vault_secret" "db" {
  name         = "db-password"
  key_vault_id = azurerm_key_vault.lab.id

  value_wo         = ephemeral.random_password.db.result # write-only: sent to Azure, never stored
  value_wo_version = var.secret_version                  # bump to push a new value

  depends_on = [azurerm_role_assignment.me_kv]
}

# --- 3. Provider-defined functions (Terraform >= 1.8) -----------------------

locals {
  vnet_id_parts = provider::azurerm::parse_resource_id(azapi_resource.vnet.id)
}

output "vnet_resource_group_from_id" {
  value = local.vnet_id_parts.resource_group_name
}

output "vnet_subnets_from_api" {
  value = azapi_resource.vnet.output.properties.subnets[*].name
}
