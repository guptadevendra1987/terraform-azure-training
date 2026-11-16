# Terraform on Azure — Cheat Sheet

## CLI

```bash
# Core workflow
terraform init [-upgrade] [-reconfigure] [-backend-config=file.hcl] [-migrate-state]
terraform fmt [-recursive] [-check -diff]
terraform validate
terraform plan [-var-file=x.tfvars] [-var 'k=v'] [-out=tfplan] [-detailed-exitcode] [-refresh-only] [-destroy]
terraform apply [tfplan] [-auto-approve] [-replace=ADDR] [-target=ADDR] [-parallelism=N]
terraform destroy [-target=ADDR]

# Inspect
terraform show [tfplan] [-json]
terraform output [-raw NAME] [-json]
terraform console
terraform graph | dot -Tpng > graph.png
terraform providers [lock -platform=linux_amd64 -platform=windows_amd64 -platform=darwin_arm64]
terraform version

# State
terraform state list | show ADDR | mv SRC DST | rm ADDR | pull | push FILE
terraform import ADDR ID
terraform force-unlock LOCK_ID
terraform plan -generate-config-out=generated.tf

# Workspaces
terraform workspace list | new NAME | select NAME | show | delete NAME

# Testing
terraform test [-filter=tests/x.tftest.hcl] [-verbose]

# Debug
TF_LOG=DEBUG TF_LOG_PATH=tf.log terraform plan
```

## Exit codes with `-detailed-exitcode`

`0` no changes · `1` error · `2` changes present

## HCL quick reference

```hcl
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
  backend "azurerm" {}                         # partial config
}

provider "azurerm" {
  features {}
  # subscription_id = "..."  or ARM_SUBSCRIPTION_ID
}

variable "name" {
  type        = string
  default     = "x"
  description = "..."
  sensitive   = false
  nullable    = false
  validation {
    condition     = length(var.name) <= 20
    error_message = "Too long."
  }
}

locals { tags = merge(var.tags, { managed_by = "terraform" }) }

resource "azurerm_resource_group" "rg" {
  for_each = toset(["a", "b"])                 # or count = 2
  name     = "rg-${each.key}"
  location = "centralindia"
  tags     = local.tags

  lifecycle {
    prevent_destroy       = false
    create_before_destroy = false
    ignore_changes        = [tags["created_on"]]
    replace_triggered_by  = [terraform_data.trigger]
    precondition {
      condition     = true
      error_message = "..."
    }
    postcondition {
      condition     = self.location != ""
      error_message = "..."
    }
  }
  depends_on = []
}

data "azurerm_client_config" "current" {}

module "net" {
  source    = "./modules/vnet"                 # or registry + version, or git::...?ref=v1.0.0
  for_each  = var.networks
  providers = { azurerm = azurerm.hub }
  name      = each.key
}

output "id" {
  value     = azurerm_resource_group.rg["a"].id
  sensitive = false
}

moved {
  from = azurerm_resource_group.old
  to   = azurerm_resource_group.new
}

import {
  to = azurerm_resource_group.legacy
  id = "/subscriptions/.../resourceGroups/rg-legacy"
}

removed {
  from = azurerm_resource_group.handed_over
  lifecycle {
    destroy = false
  }
}

check "health" {
  assert {
    condition     = true
    error_message = "..."
  }
}
```

## Expressions

```hcl
var.env == "prod" ? "P1v3" : "B1"                       # conditional
[for s in var.list : upper(s) if s != ""]               # list comprehension
{for k, v in var.map : k => v.cidr}                     # map comprehension
{for vm in var.vms : vm.role => vm.name...}             # group by
azurerm_subnet.x[*].id                                  # splat (count)
values(azurerm_subnet.x)[*].id                          # splat (for_each)
one(azurerm_public_ip.x[*].id)                          # optional single resource
try(var.obj.attr, "default")   can(regex("^a", var.s))  coalesce(var.a, "b")
merge([for k, v in var.x : { for kk, vv in v.items : "${k}/${kk}" => vv }]...)   # flatten nested maps
"%{ for x in list }${x},%{ endfor }"                    # string template directive
```

## Most-used functions

| Category | Functions |
|---|---|
| String | `format` `join` `split` `replace` `lower` `upper` `trimspace` `trimsuffix` `substr` `regex` `startswith` |
| Collection | `length` `merge` `concat` `flatten` `distinct` `keys` `values` `lookup` `contains` `zipmap` `setproduct` `one` `toset` `tomap` |
| Network | `cidrsubnet` `cidrsubnets` `cidrhost` `cidrnetmask` |
| Encoding / files | `jsonencode` `jsondecode` `yamldecode` `base64encode` `file` `templatefile` `fileset` `filemd5` |
| Azure provider | `provider::azurerm::parse_resource_id` `provider::azurerm::normalise_resource_id` |

## Azure authentication environment variables

| Scenario | Variables |
|---|---|
| CLI | `ARM_SUBSCRIPTION_ID` |
| Service principal + secret | `ARM_CLIENT_ID` `ARM_CLIENT_SECRET` `ARM_TENANT_ID` `ARM_SUBSCRIPTION_ID` |
| OIDC (GitHub, Azure DevOps) | `ARM_CLIENT_ID` `ARM_TENANT_ID` `ARM_SUBSCRIPTION_ID` `ARM_USE_OIDC=true` (+ `ARM_OIDC_TOKEN` on Azure DevOps) |
| Managed identity | `ARM_USE_MSI=true` (+ `ARM_CLIENT_ID` for user-assigned) |

## Azure resource ID formats

```text
/subscriptions/{sub}
/subscriptions/{sub}/resourceGroups/{rg}
/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnet}
/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnet}/subnets/{snet}
/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{sa}
/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{kv}
/providers/Microsoft.Management/managementGroups/{mg}
```

## Naming rules that bite

| Resource | Rule |
|---|---|
| Storage account | 3–24, lowercase letters and digits only, globally unique |
| Key Vault | 3–24, letters, digits, hyphens; globally unique; soft-deleted names stay reserved |
| App Service | 2–60, globally unique (`*.azurewebsites.net`) |
| Resource group | 1–90 |
| Firewall / Bastion subnets | Exactly `AzureFirewallSubnet` (≥ /26), `AzureBastionSubnet` (≥ /26) |
