# Fixed version of ../lab10-insecure-scan. Compare the two side by side.
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

variable "admin_source_ip" {
  type        = string
  description = "Only this CIDR may use SSH."
}

variable "sql_admin_password" {
  type      = string
  sensitive = true # supplied through TF_VAR_sql_admin_password from a pipeline secret, never a default
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "good" {
  name     = "rg-secure-demo"
  location = "centralindia"
}

resource "azurerm_storage_account" "good" {
  name                            = "stsecuredemo0001"
  resource_group_name             = azurerm_resource_group.good.name
  location                        = azurerm_resource_group.good.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  public_network_access_enabled   = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 14
    }
  }
}

resource "azurerm_network_security_group" "good" {
  name                = "nsg-secure"
  location            = azurerm_resource_group.good.location
  resource_group_name = azurerm_resource_group.good.name

  security_rule {
    name                       = "allow-ssh-from-admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_ip
    destination_address_prefix = "*"
  }
  # RDP removed entirely: use Azure Bastion for interactive access
}

resource "azurerm_key_vault" "good" {
  name                       = "kv-secure-demo-0001"
  location                   = azurerm_resource_group.good.location
  resource_group_name        = azurerm_resource_group.good.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}
