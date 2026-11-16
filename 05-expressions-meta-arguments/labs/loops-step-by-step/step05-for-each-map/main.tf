# STEP 5: for_each with a MAP OF OBJECTS. This is the pattern you will use most in production.
#
# The KEY is the identity ("web01"). The VALUE holds that item's settings.
#   each.key   → "web01"
#   each.value → { size = "Standard_B2s", disk_gb = 64, ... }

terraform {
  required_version = ">= 1.9"
}

variable "vms" {
  type = map(object({
    size    = string
    disk_gb = optional(number, 64) # optional with a default: callers can leave it out
    zone    = optional(number, 1)
    public  = optional(bool, false)
  }))

  default = {
    web01 = { size = "Standard_B2s", public = true }
    web02 = { size = "Standard_B2s", public = true, zone = 2 }
    app01 = { size = "Standard_B2ms", disk_gb = 128 }
    db01  = { size = "Standard_D4s_v5", disk_gb = 512, zone = 3 }
  }
}

resource "terraform_data" "vm" {
  for_each = var.vms

  input = {
    name    = "vm-${each.key}"
    size    = each.value.size
    disk_gb = each.value.disk_gb
    zone    = each.value.zone
    # A conditional inside the loop
    public_ip = each.value.public ? "pip-${each.key}" : "none"
  }
}

output "vm_sizes" {
  # for expression: build a new map from the resource map
  value = { for k, vm in terraform_data.vm : k => vm.output.size }
}

output "public_vms" {
  # for expression with a filter (if)
  value = [for k, vm in var.vms : k if vm.public]
}

output "total_disk_gb" {
  value = sum([for vm in var.vms : vm.disk_gb])
}

# TRY THIS
# 1. Add  app02 = { size = "Standard_B2ms" }  to the default map → plan shows 1 to add
# 2. Change db01's disk_gb to 1024 → plan shows ONLY db01 changing
# 3. terraform console → terraform_data.vm["db01"].output
