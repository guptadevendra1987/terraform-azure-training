terraform {
  required_version = ">= 1.9"
}

# Without locals each resource would repeat replace(lower(var.app_name)...) and the tag map.
# With locals: one change in locals.tf updates every resource.

resource "terraform_data" "resource_group" {
  input = { name = "rg-${local.name_prefix}", tags = local.tags }
}

resource "terraform_data" "key_vault" {
  input = { name = "kv-${local.name_prefix}", tags = local.tags }
}

resource "terraform_data" "app_service" {
  input = {
    name = "app-${local.name_prefix}"
    sku  = local.is_prod ? "P1v3" : "B1" # a readable local instead of repeating the comparison
    tags = local.tags
  }
}
