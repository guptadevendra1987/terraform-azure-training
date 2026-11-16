# Lab 15.1: connect a configuration to HCP Terraform with the cloud block (CLI-driven workflow).
#   terraform login                      → stores an API token in credentials.tfrc.json
#   terraform init                       → creates/connects the workspace; offers to migrate local state
#   terraform plan                       → runs REMOTELY in HCP Terraform; output streams to your terminal
terraform {
  required_version = ">= 1.9"

  cloud {
    organization = "REPLACE-WITH-YOUR-ORG" # or set TF_CLOUD_ORGANIZATION and remove this line

    workspaces {
      name    = "tf-azure-training-lab15"
      project = "tf-azure-training" # optional: the project is created if it does not exist
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Credentials come from the WORKSPACE (dynamic credentials or env vars), not from your laptop,
# because the run executes on HCP Terraform's infrastructure.
provider "azurerm" {
  features {}
}

variable "student" {
  type        = string
  description = "Set as a Terraform variable in the workspace (or a variable set)."
}

variable "location" {
  type    = string
  default = "centralindia"
}

resource "azurerm_resource_group" "lab15" {
  name     = "rg-${var.student}-lab15-hcp"
  location = var.location
  tags     = { course = "tf-azure-training", owner = var.student, managed_by = "hcp-terraform" }
}

output "resource_group_id" {
  value = azurerm_resource_group.lab15.id
}
