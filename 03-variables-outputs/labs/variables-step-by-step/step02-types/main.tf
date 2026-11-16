# STEP 2: types. What KIND of value is allowed?
#
#   string → "text"        number → 42           bool → true / false
#   list   → ["a", "b"]    an ordered line of items; get one with [0], [1]...
#   set    → ["a", "b"]    no order, no duplicates (good for for_each later)
#   map    → { k = "v" }   a lookup table; get one with ["key"]
#
# Analogy: the type is the shape of the hole. Terraform refuses pieces that don't fit,
# BEFORE anything is created.

terraform {
  required_version = ">= 1.9"
}

variable "vm_count" {
  type    = number
  default = 2
}

variable "enable_backup" {
  type    = bool
  default = true
}

variable "allowed_regions" {
  type    = list(string) # a list whose items are all strings
  default = ["centralindia", "southindia", "westindia"]
}

variable "teams" {
  type    = set(string)
  default = ["payments", "orders", "payments"] # the duplicate disappears!
}

variable "vm_sizes" {
  type = map(string) # every value in the map is a string
  default = {
    dev  = "Standard_B1s"
    test = "Standard_B2s"
    prod = "Standard_D4s_v5"
  }
}

output "a_number_math" {
  value = var.vm_count * 2 # numbers can do maths → 4
}

output "b_bool_choice" {
  value = var.enable_backup ? "backup ON" : "backup OFF" # condition ? if_true : if_false
}

output "c_list_first_item" {
  value = var.allowed_regions[0] # lists start at 0 → "centralindia"
}

output "d_list_length" {
  value = length(var.allowed_regions) # → 3
}

output "e_set_no_duplicates" {
  value = var.teams # → ["orders", "payments"]  (sorted, duplicate removed)
}

output "f_map_lookup" {
  value = var.vm_sizes["prod"] # → "Standard_D4s_v5"
}

output "g_map_lookup_dot" {
  value = var.vm_sizes.dev # dot style also works for simple keys → "Standard_B1s"
}

# TRY THIS: break the types and READ each error
# 1. terraform plan -var="vm_count=two"
#      → Invalid value for input variable: a number is required.
# 2. terraform plan -var="enable_backup=maybe"
#      → a bool is required.
# 3. terraform plan -var='allowed_regions=["eastus"]'          (works: one-item list)
# 4. terraform plan -var='vm_sizes={dev="B1s", prod=3}'        (works! 3 is CONVERTED to "3")
#      Terraform converts compatible values automatically: number → string is fine,
#      but "two" → number is impossible.
# 5. terraform console  →  var.vm_sizes["uat"]   → error: the key doesn't exist
#                       →  lookup(var.vm_sizes, "uat", "Standard_B1s")   → safe with a default
