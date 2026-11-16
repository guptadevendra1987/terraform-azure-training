# Integration test: creates REAL Azure resources, asserts, then destroys them automatically.
#   export ARM_SUBSCRIPTION_ID=...   (az login first)
#   terraform test -filter=tests/integration.tftest.hcl -var="student=dg"

provider "azurerm" {
  features {}
}

# Run 1: helper module creates the resource group and a unique suffix
run "setup" {
  module {
    source = "./tests/setup"
  }

  variables {
    student = var.student
  }
}

# Run 2: deploy the module under test using outputs from the setup run
run "deploy_storage" {
  command = apply

  variables {
    name                = "st${var.student}tt${run.setup.suffix}"
    location            = run.setup.location
    resource_group_name = run.setup.resource_group_name
    containers          = ["data"]
    tags                = { owner = var.student, course = "tf-azure-training" }
  }

  assert {
    condition     = startswith(output.primary_blob_endpoint, "https://st${var.student}tt")
    error_message = "Unexpected blob endpoint."
  }

  assert {
    condition     = azurerm_storage_account.this.https_traffic_only_enabled
    error_message = "HTTPS-only must be enforced in Azure."
  }
}
# Terraform destroys everything in reverse order when the test file finishes.
