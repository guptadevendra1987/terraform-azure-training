# Backend settings for prod. No secrets, so this file is committed.
resource_group_name  = "rg-dg-tfstate"
storage_account_name = "stdgtfstateXXXXX"
container_name       = "tfstate"
key                  = "lab09/app-prod.tfstate"
use_azuread_auth     = true
