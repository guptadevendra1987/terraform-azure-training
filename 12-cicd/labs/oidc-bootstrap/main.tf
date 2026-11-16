# Creates the identity that CI/CD pipelines use to run Terraform, with OIDC (no secrets).
# Run once from your laptop:  terraform apply -var-file=bootstrap.tfvars
terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

variable "student" {
  type = string
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in the form <owner>/<repo>."
}

variable "environments" {
  type        = set(string)
  description = "GitHub environments that may deploy (one federated credential each)."
  default     = ["dev", "prod", "prod-readonly"]
}

variable "state_storage_account_id" {
  type        = string
  description = "Resource ID of the remote-state storage account from Module 06."
}

variable "azure_devops" {
  description = "Optional: Azure DevOps workload identity federation (issuer and subject come from the service connection page)."
  type = object({
    issuer  = string
    subject = string
  })
  default = null
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

resource "azuread_application" "cicd" {
  display_name = "app-${var.student}-terraform-cicd"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "cicd" {
  client_id = azuread_application.cicd.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

# Trust GitHub's OIDC tokens for pull requests (plan only) ...
resource "azuread_application_federated_identity_credential" "github_pr" {
  application_id = azuread_application.cicd.id
  display_name   = "github-pull-request"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repo}:pull_request"
}

# ... for plan jobs on pushes to main ...
resource "azuread_application_federated_identity_credential" "github_main" {
  application_id = azuread_application.cicd.id
  display_name   = "github-branch-main"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repo}:ref:refs/heads/main"
}

# ... and for jobs that run in a GitHub environment (apply, behind approvals)
resource "azuread_application_federated_identity_credential" "github_env" {
  for_each = var.environments

  application_id = azuread_application.cicd.id
  display_name   = "github-env-${each.key}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repo}:environment:${each.key}"
}

resource "azuread_application_federated_identity_credential" "azure_devops" {
  count = var.azure_devops == null ? 0 : 1

  application_id = azuread_application.cicd.id
  display_name   = "azure-devops"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.azure_devops.issuer
  subject        = var.azure_devops.subject
}

# Least privilege: Contributor to deploy resources. Add "Role Based Access Control Administrator"
# (with a condition) only if your stacks create role assignments.
resource "azurerm_role_assignment" "cicd_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.cicd.object_id
}

# Data-plane access to the remote state
resource "azurerm_role_assignment" "cicd_state" {
  scope                = var.state_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.cicd.object_id
}

output "github_secrets" {
  description = "Add these as GitHub repository VARIABLES (they are not secret)."
  value = {
    AZURE_CLIENT_ID       = azuread_application.cicd.client_id
    AZURE_TENANT_ID       = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID = data.azurerm_subscription.current.subscription_id
  }
}
