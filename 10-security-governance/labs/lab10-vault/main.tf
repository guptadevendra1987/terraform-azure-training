# Lab 10.4: inject secrets from HashiCorp Vault (exam objective 4h).
#
# Prerequisites (local Vault dev server, in-memory, NOT for production):
#   vault server -dev -dev-root-token-id=root            (or: docker run -p 8200:8200 -e VAULT_DEV_ROOT_TOKEN_ID=root hashicorp/vault)
#   export VAULT_ADDR=http://127.0.0.1:8200  VAULT_TOKEN=root
#   vault kv put secret/payments/db username=pay_admin password='S3cr3t-From-Vault!'
#
# Part 1 (classic): data source    → the secret is copied into Terraform STATE
# Part 2 (modern):  ephemeral + _wo → the secret is NEVER written to plan or state (Terraform >= 1.11)
terraform {
  required_version = ">= 1.11"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Address and token come from VAULT_ADDR / VAULT_TOKEN. Never hard-code a Vault token.
provider "vault" {}

provider "azurerm" {
  features {}
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault from Lab 10.1 (you need the Key Vault Secrets Officer role on it)."
}

variable "key_vault_resource_group" {
  type        = string
  description = "Resource group of that Key Vault, e.g. rg-dg-lab10."
}

variable "secret_version" {
  type        = number
  description = "Increase to push a new value from Vault into Key Vault."
  default     = 1
}

# --- Part 1: classic data source (the value lands in state) -----------------
# EXPECTED: terraform validate warns "Deprecated. Please use new Ephemeral KVV2 Secret resource".
# HashiCorp deprecated this data source BECAUSE it copies secrets into state. That is the lesson of Part 1.

data "vault_kv_secret_v2" "db_classic" {
  mount = "secret"
  name  = "payments/db"
}

output "db_username" {
  value = data.vault_kv_secret_v2.db_classic.data["username"] # not secret, fine to show
}

# Run: terraform state pull | grep -c "S3cr3t-From-Vault"   → 1 or more. The password is IN STATE.

# --- Part 2: ephemeral resource + write-only argument (never stored) --------

ephemeral "vault_kv_secret_v2" "db" {
  mount = "secret"
  name  = "payments/db"
}

data "azurerm_key_vault" "lab" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "payments-db-password"
  key_vault_id = data.azurerm_key_vault.lab.id

  value_wo         = ephemeral.vault_kv_secret_v2.db.data["password"]
  value_wo_version = var.secret_version
}

# Run: terraform state pull | grep -c "S3cr3t-From-Vault"
#   With Part 1 commented out → 0. Vault is the source of truth, Key Vault gets the value, state stays clean.
