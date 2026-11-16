# Lab 15.3: read another workspace's outputs (the "app" workspace consuming the "network" workspace).
# Two options; tfe_outputs is preferred because it needs only output-read permission, not the full state.
terraform {
  required_version = ">= 1.9"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.84"
    }
  }
}

variable "organization" {
  type = string
}

variable "network_workspace" {
  type    = string
  default = "dg-network-dev"
}

# Option A (preferred): tfe_outputs data source
data "tfe_outputs" "network" {
  organization = var.organization
  workspace    = var.network_workspace
}

# Option B (classic, also on the exam): terraform_remote_state with the "remote" backend
data "terraform_remote_state" "network" {
  backend = "remote"
  config = {
    organization = var.organization
    workspaces = {
      name = var.network_workspace
    }
  }
}

output "subnet_ids_via_tfe_outputs" {
  value     = data.tfe_outputs.network.values.subnet_ids # tfe_outputs marks all values sensitive
  sensitive = true
}

output "subnet_ids_via_remote_state" {
  value = data.terraform_remote_state.network.outputs.subnet_ids
}
