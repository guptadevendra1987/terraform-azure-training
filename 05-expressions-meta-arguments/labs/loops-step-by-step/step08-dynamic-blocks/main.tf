# STEP 8: dynamic blocks, which are loops INSIDE a resource.
#
# count and for_each repeat a WHOLE RESOURCE.
# dynamic repeats a NESTED BLOCK inside one resource (security_rule, ip_configuration, ...).
#
# Before (static):                      After (dynamic):
#   security_rule { ...https... }        dynamic "security_rule" {
#   security_rule { ...http...  }          for_each = local.rules
#   security_rule { ...ssh...   }          content { ...security_rule.value.xxx... }
#                                        }
#
# This step uses the real azurerm provider. Run "terraform plan" only (needs az login + ARM_SUBSCRIPTION_ID).
# Nothing is created.

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

locals {
  # Production pattern: the security team owns this list (later moved to a YAML/JSON file)
  rules = [
    { name = "allow-https", priority = 100, port = "443", source = "Internet" },
    { name = "allow-http", priority = 110, port = "80", source = "Internet" },
    { name = "allow-ssh-vpn", priority = 120, port = "22", source = "10.250.0.0/16" },
  ]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web-demo"
  location            = "centralindia"
  resource_group_name = "rg-does-not-need-to-exist-for-plan"

  dynamic "security_rule" {                                 # the name of the nested block to repeat
    for_each = local.rules                                  # what to loop over
    content {                                               # the body of ONE block
      name                       = security_rule.value.name # the iterator is named after the block
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = security_rule.value.source
      destination_address_prefix = "*"
    }
  }
}

# TRY THIS
# 1. terraform init && terraform plan  → the NSG shows 3 security_rule blocks
# 2. Add a 4th rule to the list → still ONE resource, now 4 blocks
# 3. Rename the iterator: add  iterator = rule  under for_each and use rule.value.name
# 4. Optional block (0 or 1): for_each = var.enable_x ? [1] : []  is the dynamic version of count
