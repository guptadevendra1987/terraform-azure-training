# Mocked tests for the whole capstone composition: no Azure needed.
#   terraform init -backend=false && terraform test

# The real azurerm schema (including resource-ID validators) still applies under a mock,
# so give every referenced resource a realistically shaped ID.
mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
    }
  }
  mock_resource "azurerm_virtual_network" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
    }
  }
  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
    }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/nsg-test"
    }
  }
  mock_resource "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    }
  }
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/sttest"
    }
  }
  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-test"
    }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
    }
  }
  mock_resource "azurerm_linux_web_app" {
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/app-test"
      default_hostname = "app-test.azurewebsites.net"
    }
  }
}

mock_provider "random" {}

variables {
  student           = "tst"
  environment       = "dev"
  hub_address_space = "10.200.0.0/16"
  spokes = {
    web = {
      address_space = "10.201.0.0/16"
      subnets = {
        app = { netnum = 1, delegation = "Microsoft.Web/serverFarms" }
        pe  = { netnum = 2 }
      }
    }
  }
}

run "dev_has_no_firewall_and_no_lock" {
  command = apply

  assert {
    condition     = output.firewall_private_ip == null
    error_message = "Dev must not deploy Azure Firewall."
  }

  assert {
    condition     = length(azurerm_management_lock.hub) == 0
    error_message = "Dev hub must not be locked."
  }

  assert {
    condition     = length(module.spoke["web"].subnet_ids) == 2
    error_message = "Web spoke should have app and pe subnets."
  }
}

run "prod_locks_the_hub" {
  command = apply

  variables {
    environment = "prod"
  }

  assert {
    condition     = length(azurerm_management_lock.hub) == 1
    error_message = "Prod hub must have a CanNotDelete lock."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.shared.retention_in_days == 90
    error_message = "Prod log retention must be 90 days."
  }
}

run "rejects_spoke_without_pe_subnet" {
  command = plan

  variables {
    spokes = {
      web = {
        address_space = "10.201.0.0/16"
        subnets       = { app = { netnum = 1 } }
      }
    }
  }

  expect_failures = [var.spokes]
}
