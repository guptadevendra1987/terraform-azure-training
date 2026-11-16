# Lab 15.2: manage HCP Terraform ITSELF as code (production platform-team pattern).
# Creates: project, two workspaces (network → app), a variable set, a run trigger,
# a team with project access, Azure dynamic credentials (OIDC, no secrets) and a policy set.
#
#   export TFE_TOKEN=<user or team token>      (or rely on `terraform login`)
#   terraform init && terraform apply -var="organization=<org>" -var="student=dg"
terraform {
  required_version = ">= 1.9"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.84"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "tfe" {
  organization = var.organization
}

provider "azuread" {}

provider "azurerm" {
  features {}
}

variable "organization" {
  type        = string
  description = "Your HCP Terraform organization name."
}

variable "student" {
  type = string
}

variable "github_repo" {
  type        = string
  description = "Optional VCS repo <owner>/<repo> for the network workspace. Empty = CLI-driven."
  default     = ""
}

variable "github_oauth_token_id" {
  type        = string
  description = "OAuth token ID of the VCS connection (Organization settings → VCS providers)."
  default     = ""
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

locals {
  project    = "tf-azure-training-${var.student}"
  workspaces = ["network", "app"]
}

# --- Project & workspaces ---------------------------------------------------

resource "tfe_project" "training" {
  name = local.project
}

resource "tfe_workspace" "this" {
  for_each = toset(local.workspaces)

  name              = "${var.student}-${each.key}-dev"
  project_id        = tfe_project.training.id
  description       = "${each.key} stack (dev) for ${var.student}"
  terraform_version = "~> 1.12"
  working_directory = "infra/${each.key}"
  auto_apply        = each.key == "network" # app changes always need a human to confirm
  queue_all_runs    = false

  # VCS-driven workflow when a repo is provided, otherwise CLI/API-driven
  dynamic "vcs_repo" {
    for_each = var.github_repo != "" && each.key == "network" ? [1] : []
    content {
      identifier     = var.github_repo
      branch         = "main"
      oauth_token_id = var.github_oauth_token_id
    }
  }
}

resource "tfe_workspace_settings" "this" {
  for_each = tfe_workspace.this

  workspace_id   = each.value.id
  execution_mode = "remote"
}

# Run trigger: a successful apply in "network" queues a run in "app"
resource "tfe_run_trigger" "network_to_app" {
  workspace_id  = tfe_workspace.this["app"].id
  sourceable_id = tfe_workspace.this["network"].id
}

# --- Variable set shared by every workspace in the project ------------------

resource "tfe_variable_set" "common" {
  name        = "${local.project}-common"
  description = "Region, tags and Azure dynamic credentials shared by all ${local.project} workspaces"
}

resource "tfe_project_variable_set" "common" {
  project_id      = tfe_project.training.id
  variable_set_id = tfe_variable_set.common.id
}

resource "tfe_variable" "location" {
  variable_set_id = tfe_variable_set.common.id
  category        = "terraform"
  key             = "location"
  value           = "centralindia"
}

resource "tfe_variable" "student" {
  variable_set_id = tfe_variable_set.common.id
  category        = "terraform"
  key             = "student"
  value           = var.student
}

# --- Azure dynamic provider credentials (OIDC: no client secret anywhere) ---

resource "azuread_application" "hcp" {
  display_name = "app-${var.student}-hcp-terraform"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "hcp" {
  client_id = azuread_application.hcp.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

# One federated credential per workspace and run phase (plan / apply)
resource "azuread_application_federated_identity_credential" "hcp" {
  for_each = {
    for pair in setproduct(local.workspaces, ["plan", "apply"]) : "${pair[0]}-${pair[1]}" => {
      workspace = tfe_workspace.this[pair[0]].name
      phase     = pair[1]
    }
  }

  application_id = azuread_application.hcp.id
  display_name   = "hcp-${each.key}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://app.terraform.io"
  subject        = "organization:${var.organization}:project:${local.project}:workspace:${each.value.workspace}:run_phase:${each.value.phase}"
}

resource "azurerm_role_assignment" "hcp_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.hcp.object_id
}

# Environment variables that switch on dynamic credentials in every workspace of the project
resource "tfe_variable" "azure_auth" {
  for_each = {
    TFC_AZURE_PROVIDER_AUTH = "true"
    TFC_AZURE_RUN_CLIENT_ID = azuread_application.hcp.client_id
    ARM_SUBSCRIPTION_ID     = data.azurerm_subscription.current.subscription_id
    ARM_TENANT_ID           = data.azurerm_client_config.current.tenant_id
  }

  variable_set_id = tfe_variable_set.common.id
  category        = "env"
  key             = each.key
  value           = each.value
}

# --- Team & permissions -----------------------------------------------------

resource "tfe_team" "app_developers" {
  name       = "${var.student}-app-developers"
  visibility = "organization"
}

resource "tfe_team_project_access" "app_developers" {
  team_id    = tfe_team.app_developers.id
  project_id = tfe_project.training.id
  access     = "write" # read | write | maintain | admin | custom
}

# --- Policy as code (Sentinel), enforced on this project's workspaces -------

resource "tfe_policy" "require_tags" {
  name         = "${var.student}-require-owner-tag"
  description  = "Every Azure resource group must have an owner tag"
  kind         = "sentinel"
  policy       = file("${path.module}/policies/require-owner-tag.sentinel")
  enforce_mode = "soft-mandatory" # advisory | soft-mandatory | hard-mandatory
}

resource "tfe_policy_set" "training" {
  name          = "${var.student}-training-guardrails"
  description   = "Guardrails for ${local.project}"
  kind          = "sentinel"
  policy_ids    = [tfe_policy.require_tags.id]
  workspace_ids = [for w in tfe_workspace.this : w.id]
}

output "workspaces" {
  value = { for k, w in tfe_workspace.this : k => w.html_url }
}
