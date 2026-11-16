# Backend settings for dev. No secrets, so this file is committed.
resource_group_name  = "rg-dg-tfstate"
storage_account_name = "stdgtfstateXXXXX"
container_name       = "tfstate"
key                  = "lab09/app-dev.tfstate"
use_azuread_auth     = true
