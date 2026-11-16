# INTENTIONALLY INSECURE: scan it with checkov / trivy / tflint, then fix every finding.
#   checkov -d .      trivy config .      tflint --init && tflint
# Do NOT apply this as-is. The fixed version is in ../lab10-insecure-scan-fixed.
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

resource "azurerm_resource_group" "bad" {
  name     = "rg-insecure-demo"
  location = "centralindia"
}

resource "azurerm_storage_account" "bad" {
  name                            = "stinsecuredemo0001"
  resource_group_name             = azurerm_resource_group.bad.name
  location                        = azurerm_resource_group.bad.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_0" # finding: old TLS
  https_traffic_only_enabled      = false    # finding: HTTP allowed
  allow_nested_items_to_be_public = true     # finding: public blobs
}

resource "azurerm_network_security_group" "bad" {
  name                = "nsg-insecure"
  location            = azurerm_resource_group.bad.location
  resource_group_name = azurerm_resource_group.bad.name

  security_rule {
    name                       = "allow-ssh-from-anywhere" # finding: SSH open to the internet
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-rdp-from-anywhere" # finding: RDP open to the internet
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_key_vault" "bad" {
  name                       = "kv-insecure-demo-0001"
  location                   = azurerm_resource_group.bad.location
  resource_group_name        = azurerm_resource_group.bad.name
  tenant_id                  = "00000000-0000-0000-0000-000000000000" # finding: hard-coded tenant
  sku_name                   = "standard"
  purge_protection_enabled   = false # finding: no purge protection
  soft_delete_retention_days = 7
  # finding: no network_acls (public access from anywhere), access policies instead of RBAC
}

variable "sql_admin_password" {
  type    = string
  default = "P@ssw0rd1234!" # finding: secret in code, not marked sensitive
}
