# STEP 1: your first variable.
#
# A variable is an INPUT to your configuration, like a form field.
# The code stays the same, and only the answers on the form change.
#
#   variable "name" { ... }   → DECLARES the input (what it's called, what type, default answer)
#   var.name                  → USES the input's value
#
# Run:  terraform init && terraform apply -auto-approve
# terraform_data is built into Terraform: no Azure account and no provider download needed.

terraform {
  required_version = ">= 1.9"
}

variable "app_name" {
  type        = string                     # what kind of value: text
  description = "Name of the application." # shows up in prompts and docs. Always write one!
  default     = "shop"                     # used when nobody provides a value
}

variable "environment" {
  type        = string
  description = "Where we deploy: dev, test or prod."
  # No default: Terraform MUST get a value from somewhere, or it will ask you
}

# Use the variables. ${...} inserts a value inside a string
resource "terraform_data" "resource_group" {
  input = "rg-${var.app_name}-${var.environment}"
}

output "resource_group_name" {
  value = terraform_data.resource_group.output
}

# TRY THIS (in order)
# 1. terraform apply
#      → Terraform PROMPTS: "var.environment  Where we deploy: dev, test or prod.  Enter a value:"
#        (it shows your description!). Type dev   → rg-shop-dev
#
# 2. terraform apply -auto-approve -var="environment=prod"
#      → no prompt. Output: rg-shop-prod
#
# 3. terraform apply -auto-approve -var="environment=prod" -var="app_name=payments"
#      → the default "shop" is overridden. Output: rg-payments-prod
#
# 4. terraform plan -input=false
#      → ERROR "No value for required variable". This is how pipelines behave: they never prompt.
