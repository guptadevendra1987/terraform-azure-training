# STEP 6: for EXPRESSIONS. These TRANSFORM DATA and create no resources.
#
# Analogy: an Excel formula you drag down a column. Input data in, new data out.
#
#   [for ITEM in COLLECTION : RESULT]            → produces a LIST   (square brackets)
#   {for ITEM in COLLECTION : KEY => VALUE}      → produces a MAP    (curly braces)
#   ... add  "if CONDITION"  at the end to filter

terraform {
  required_version = ">= 1.9"
}

locals {
  apps = ["Payments", "Orders", "Catalog"]

  subnets = {
    web  = { cidr = "10.0.1.0/24", public = true }
    app  = { cidr = "10.0.2.0/24", public = false }
    data = { cidr = "10.0.3.0/24", public = false }
  }

  vms = [
    { name = "web01", role = "web", env = "prod" },
    { name = "web02", role = "web", env = "prod" },
    { name = "app01", role = "app", env = "prod" },
    { name = "app02", role = "app", env = "dev" },
  ]
}

output "e1_list_to_list" {
  description = "Transform every item"
  value       = [for a in local.apps : lower(a)]
  # → ["payments", "orders", "catalog"]
}

output "e2_list_with_index" {
  description = "Two variables in a list loop: index and value"
  value       = [for i, a in local.apps : "${i + 1}. ${a}"]
  # → ["1. Payments", "2. Orders", "3. Catalog"]
}

output "e3_list_to_map" {
  description = "Turn a list into a map (very common before for_each)"
  value       = { for a in local.apps : lower(a) => "rg-${lower(a)}-prod" }
  # → { payments = "rg-payments-prod", ... }
}

output "e4_map_to_list" {
  description = "Two variables in a map loop: key and value"
  value       = [for name, s in local.subnets : "${name}: ${s.cidr}"]
  # → ["app: 10.0.2.0/24", "data: 10.0.3.0/24", "web: 10.0.1.0/24"]  (maps are sorted by key)
}

output "e5_filter" {
  description = "Keep only matching items with if"
  value       = { for name, s in local.subnets : name => s.cidr if !s.public }
  # → { app = "10.0.2.0/24", data = "10.0.3.0/24" }
}

output "e6_list_of_objects_to_map" {
  description = "THE production pattern: list of objects → map keyed by a unique field → for_each"
  value       = { for vm in local.vms : vm.name => vm }
}

output "e7_group_by" {
  description = "The ... after the value groups duplicates into lists"
  value       = { for vm in local.vms : vm.role => vm.name... }
  # → { app = ["app01", "app02"], web = ["web01", "web02"] }
}

output "e8_filter_and_transform" {
  description = "Prod VM names in upper case"
  value       = [for vm in local.vms : upper(vm.name) if vm.env == "prod"]
}

# TRY THIS: terraform apply -auto-approve, then predict each output BEFORE reading it.
# Then write your own in terraform console:
#   > [for s in local.subnets : s.cidr]
#   > {for vm in local.vms : vm.name => vm.env if vm.role == "app"}
