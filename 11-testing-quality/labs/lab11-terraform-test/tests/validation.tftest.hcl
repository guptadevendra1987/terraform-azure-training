# Negative tests: prove that bad input is rejected with the expected error.
mock_provider "azurerm" {}

variables {
  name                = "sttest001"
  location            = "centralindia"
  resource_group_name = "rg-test"
  tags                = { owner = "test" }
}

run "rejects_invalid_replication_type" {
  command = plan

  variables {
    replication_type = "SUPER"
  }

  expect_failures = [var.replication_type]
}

run "rejects_uppercase_name" {
  command = plan

  variables {
    name = "StTest001"
  }

  expect_failures = [azurerm_storage_account.this]
}

run "rejects_missing_owner_tag" {
  command = plan

  variables {
    tags = { team = "x" }
  }

  expect_failures = [azurerm_storage_account.this]
}
