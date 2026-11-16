# STEP 3: objects. Group related settings into ONE variable.
#
# Instead of 5 separate variables (vm_size, vm_disk_gb, vm_zone, vm_public_ip, vm_os)...
# ...one object variable whose ATTRIBUTES can each have their own type:
#
#   object({ size = string, disk_gb = number, public_ip = bool })
#
# optional(type, default) means "the caller may leave this out, and then the default is used".

terraform {
  required_version = ">= 1.9"
}

# --- 3a. One object ----------------------------------------------------------

variable "vm" {
  description = "Settings for the web VM."
  type = object({
    size      = string                # required: the caller MUST give it
    disk_gb   = optional(number, 64)  # optional: 64 if missing
    public_ip = optional(bool, false) # optional: false if missing
    zones     = optional(list(string), ["1"])
  })
  default = {
    size = "Standard_B2s" # only the required attribute. The others take their defaults
  }
}

# --- 3b. A map of objects: many items, each with the same shape --------------
# This is THE most common production pattern (and what for_each loves in Module 05).

variable "storage_accounts" {
  description = "Storage accounts keyed by short name."
  type = map(object({
    replication = optional(string, "LRS")
    containers  = optional(list(string), [])
  }))
  default = {
    logs   = {} # all defaults
    images = { containers = ["product-photos", "thumbnails"] }
    backup = { replication = "GRS", containers = ["daily"] }
  }
}

output "a_vm_full_settings" {
  value = var.vm # see the defaults filled in: disk_gb = 64, public_ip = false, zones = ["1"]
}

output "b_vm_size_only" {
  value = var.vm.size # object.attribute
}

output "c_backup_replication" {
  value = var.storage_accounts["backup"].replication # map["key"].attribute → "GRS"
}

output "d_logs_containers" {
  value = var.storage_accounts["logs"].containers # → [] (the default)
}

# TRY THIS
# 1. terraform apply -auto-approve      → read the outputs. Where did the 64 come from?
# 2. terraform plan -var='vm={disk_gb=128}'
#      → ERROR: attribute "size" is required. Optional ones can be skipped, required ones can't.
# 3. terraform plan -var='vm={size="Standard_B1s", colour="blue"}'
#      → NO error! Unknown attributes are silently DROPPED.
#        Danger: a typo like  dsik_gb = 500  is ignored and you quietly get the default 64 GB.
#        Always check the plan output, and add validation for important values (step 4).
# 4. In terraform console:  var.storage_accounts["images"]
