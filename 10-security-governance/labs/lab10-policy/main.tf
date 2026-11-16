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

variable "student" {
  type = string
}

variable "include_cost_center" {
  type        = bool
  description = "Set false to watch the Deny policy block the test VNet."
  default     = true
}

resource "azurerm_resource_group" "governed" {
  name     = "rg-${var.student}-lab10-policy"
  location = "centralindia"
  tags     = { course = "tf-azure-training", owner = var.student }
}

# --- Custom policy: every resource must carry a cost_center tag ------------

resource "azurerm_policy_definition" "require_cost_center" {
  name         = "${var.student}-require-cost-center-tag"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "[${var.student}] Require cost_center tag on resources"

  metadata = jsonencode({ category = "Tags", version = "1.0.0" })

  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
  })

  policy_rule = jsonencode({
    if = {
      field  = "tags['cost_center']"
      exists = "false"
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "require_cost_center" {
  name                 = "require-cost-center"
  resource_group_id    = azurerm_resource_group.governed.id
  policy_definition_id = azurerm_policy_definition.require_cost_center.id
  display_name         = "Require cost_center tag (Deny)"

  parameters = jsonencode({
    effect = { value = "Deny" }
  })

  non_compliance_message {
    content = "All resources must have a cost_center tag. Add it to local.tags."
  }
}

# --- Built-in policy: allowed locations ------------------------------------

data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations-india"
  resource_group_id    = azurerm_resource_group.governed.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id

  parameters = jsonencode({
    listOfAllowedLocations = { value = ["centralindia", "southindia"] }
  })
}

# --- Test resource: toggle the tag to see the Deny in action ---------------

resource "azurerm_virtual_network" "test" {
  name                = "vnet-${var.student}-policy-test"
  location            = azurerm_resource_group.governed.location
  resource_group_name = azurerm_resource_group.governed.name
  address_space       = ["10.70.0.0/16"]

  tags = merge(
    { owner = var.student },
    var.include_cost_center ? { cost_center = "cc-1001" } : {}
  )

  depends_on = [azurerm_resource_group_policy_assignment.require_cost_center]
}
