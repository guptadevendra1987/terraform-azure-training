# STEP 4: for_each with a SET. Each copy gets a NAME TAG instead of a number.
#
# Analogy: for_each is a wall of LOCKERS with name tags. Remove the "stlogs" locker
# and the other lockers do not move.

terraform {
  required_version = ">= 1.9"
}

variable "storage_accounts" {
  type    = set(string) # a set has no order and no duplicates
  default = ["stlogs", "stimages", "stbackups"]
}

resource "terraform_data" "storage" {
  for_each = var.storage_accounts # for_each needs a SET or a MAP. A list must go through toset()

  # With a set: each.key == each.value == the string
  triggers_replace = each.key
  input            = { name = each.value }
}

# Address by KEY, not by number
output "images_account" {
  value = terraform_data.storage["stimages"].output.name
}

# A for_each resource is a MAP of instances. Turn it into a list of names:
output "all_names" {
  value = [for s in terraform_data.storage : s.output.name]
}

# REPEAT THE EXPERIMENT FROM STEP 3
# 1. terraform apply -auto-approve
# 2. terraform plan -var='storage_accounts=["stimages","stbackups"]'
#
#      terraform_data.storage["stlogs"] will be destroyed
#      Plan: 0 to add, 0 to change, 1 to destroy        ← exactly what you wanted
#
# 3. terraform state list   → storage["stbackups"], storage["stimages"], storage["stlogs"]
