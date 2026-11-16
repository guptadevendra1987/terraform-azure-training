# STEP 3: the count TRAP. Why count over a list of NAMES is dangerous.
#
# triggers_replace mimics an Azure resource name: changing a name forces destroy + recreate.

terraform {
  required_version = ">= 1.9"
}

variable "storage_accounts" {
  type    = list(string)
  default = ["stlogs", "stimages", "stbackups"]
}

resource "terraform_data" "storage" {
  count = length(var.storage_accounts)

  triggers_replace = var.storage_accounts[count.index] # "the name"
  input            = { name = var.storage_accounts[count.index] }
}

output "addresses" {
  value = { for i, s in terraform_data.storage : "storage[${i}]" => s.output.name }
}

# EXPERIMENT (do it!)
# 1. terraform apply -auto-approve
#      storage[0] = stlogs, storage[1] = stimages, storage[2] = stbackups
#
# 2. Remove "stlogs" (the FIRST item) and run: terraform plan -var='storage_accounts=["stimages","stbackups"]'
#
#      storage[0]: stlogs   → stimages   must be REPLACED   ← data loss in real life!
#      storage[1]: stimages → stbackups  must be REPLACED   ← data loss in real life!
#      storage[2]: stbackups             DESTROYED
#      Plan: 2 to add, 0 to change, 3 to destroy
#
#   You wanted to delete ONE storage account. Terraform deletes and recreates ALL THREE,
#   because every item after the removed one moved down one index.
#
# Step 4 fixes this with for_each.
