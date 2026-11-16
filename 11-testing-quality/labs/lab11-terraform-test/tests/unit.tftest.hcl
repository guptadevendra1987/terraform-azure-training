# Unit tests: no Azure access needed. The azurerm provider is replaced by a mock.
#   terraform init && terraform test -filter=tests/unit.tftest.hcl

mock_provider "azurerm" {
  # Give computed attributes realistic values so assertions and check blocks work
  mock_resource "azurerm_storage_account" {
    defaults = {
      id                         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/sttest001"
      primary_blob_endpoint      = "https://sttest001.blob.core.windows.net/"
      https_traffic_only_enabled = true
    }
  }
}

# Shared inputs for every run block (each run can override)
variables {
  name                = "sttest001"
  location            = "centralindia"
  resource_group_name = "rg-test"
  tags                = { owner = "test" }
}

# Mocked runs use "apply": it is free and makes computed values (ids, endpoints) known,
# which the check block in main.tf needs. A mocked "plan" leaves them unknown.
run "secure_defaults" {
  command = apply

  assert {
    condition     = azurerm_storage_account.this.min_tls_version == "TLS1_2"
    error_message = "TLS must be 1.2."
  }

  assert {
    condition     = azurerm_storage_account.this.https_traffic_only_enabled
    error_message = "HTTPS-only must be enforced."
  }

  assert {
    condition     = azurerm_storage_account.this.allow_nested_items_to_be_public == false
    error_message = "Public blob access must be disabled."
  }

  assert {
    condition     = azurerm_storage_account.this.account_replication_type == "LRS"
    error_message = "Default replication should be LRS."
  }

  assert {
    condition     = azurerm_storage_account.this.network_rules[0].default_action == "Allow"
    error_message = "Without allow-lists the firewall default should be Allow."
  }
}

run "firewall_denies_when_allow_list_given" {
  command = apply

  variables {
    allowed_ip_ranges = ["203.0.113.0/24"]
  }

  assert {
    condition     = azurerm_storage_account.this.network_rules[0].default_action == "Deny"
    error_message = "Firewall must default to Deny when IP ranges are supplied."
  }
}

run "creates_one_container_per_name" {
  command = apply

  variables {
    containers = ["raw", "curated", "archive"]
  }

  assert {
    condition     = length(azurerm_storage_container.this) == 3
    error_message = "Expected 3 containers."
  }

  assert {
    condition     = toset(keys(output.container_ids)) == toset(["raw", "curated", "archive"])
    error_message = "container_ids output must be keyed by container name."
  }
}
