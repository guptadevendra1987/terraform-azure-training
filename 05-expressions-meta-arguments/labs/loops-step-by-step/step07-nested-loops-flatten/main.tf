# STEP 7: NESTED DATA with flatten. "Every app, in every environment."
#
# for_each loops over ONE level only. When the data has two levels
# (apps → environments, vnets → subnets, NSGs → rules), you:
#   1. loop over both levels to build a list of lists
#   2. flatten() it into one flat list          (analogy: unpack boxes inside boxes)
#   3. turn the list into a map with a UNIQUE KEY that combines both levels
#   4. use that map in for_each

terraform {
  required_version = ">= 1.9"
}

locals {
  apps         = ["payments", "orders"]
  environments = ["dev", "test", "prod"]

  # --- Pattern A: two simple lists → every combination ---------------------
  # setproduct gives every pair: [["payments","dev"], ["payments","test"], ...]
  app_env_pairs = setproduct(local.apps, local.environments)

  app_env_map = {
    for pair in local.app_env_pairs : "${pair[0]}-${pair[1]}" => {
      app = pair[0]
      env = pair[1]
    }
  }

  # --- Pattern B: nested objects → flatten ---------------------------------
  vnets = {
    hub = {
      cidr    = "10.0.0.0/16"
      subnets = { firewall = "10.0.0.0/26", shared = "10.0.1.0/24" }
    }
    spoke = {
      cidr    = "10.1.0.0/16"
      subnets = { web = "10.1.1.0/24", app = "10.1.2.0/24", data = "10.1.3.0/24" }
    }
  }

  # 1 + 2: inner loop builds a list per vnet; flatten merges them into one list
  subnet_list = flatten([
    for vnet_name, vnet in local.vnets : [
      for subnet_name, cidr in vnet.subnets : {
        vnet   = vnet_name
        subnet = subnet_name
        cidr   = cidr
      }
    ]
  ])

  # 3: a unique key that combines both levels: "spoke/web"
  subnet_map = { for s in local.subnet_list : "${s.vnet}/${s.subnet}" => s }
}

# 4: one resource per app per environment (6 total)
resource "terraform_data" "resource_group" {
  for_each = local.app_env_map
  input    = { name = "rg-${each.value.app}-${each.value.env}" }
}

# 4: one resource per subnet across all VNets (5 total)
resource "terraform_data" "subnet" {
  for_each = local.subnet_map
  input    = "snet-${each.value.subnet} (${each.value.cidr}) in vnet-${each.value.vnet}"
}

output "resource_groups" {
  value = [for rg in terraform_data.resource_group : rg.output.name]
}

output "subnet_list_before_map" {
  value = local.subnet_list
}

output "subnets" {
  value = { for k, s in terraform_data.subnet : k => s.output }
}

# TRY THIS
# 1. terraform console → local.subnet_list   (then remove flatten() in the console and compare)
# 2. Add "uat" to environments → plan shows 2 to add (one per app)
# 3. Add a subnet "mgmt" to hub → plan shows 1 to add, key "hub/mgmt"
