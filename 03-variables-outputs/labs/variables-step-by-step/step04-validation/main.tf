# STEP 4: validation. Reject BAD values with a FRIENDLY message.
#
# The type checks the SHAPE ("is it a string?").
# Validation checks the CONTENT ("is it one of dev/test/prod?").
#
#   validation {
#     condition     = <expression that must be true>
#     error_message = "What went wrong and how to fix it."
#   }
#
# Analogy: a form that says "Phone number must be 10 digits" instead of crashing later.

terraform {
  required_version = ">= 1.9"
}

# Rule 1: allowed values (a pick list)
variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

# Rule 2: a pattern (regex). can() turns "error" into false
variable "owner_initials" {
  type    = string
  default = "dg"

  validation {
    condition     = can(regex("^[a-z]{2,4}$", var.owner_initials))
    error_message = "owner_initials must be 2-4 lowercase letters, e.g. \"dg\"."
  }
}

# Rule 3: a number range. You can have SEVERAL validation blocks on one variable
variable "disk_gb" {
  type    = number
  default = 64

  validation {
    condition     = var.disk_gb >= 32
    error_message = "disk_gb must be at least 32."
  }

  validation {
    condition     = var.disk_gb <= 1024
    error_message = "disk_gb must be at most 1024 (ask the platform team for bigger disks)."
  }
}

# Rule 4: check EVERY item in a list with alltrue([...])
variable "admin_cidrs" {
  type    = list(string)
  default = ["10.250.0.0/16"]

  validation {
    condition     = alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0))])
    error_message = "Every admin_cidrs entry must be a valid CIDR such as 10.0.0.0/16."
  }
}

# Rule 5: depend on ANOTHER variable (Terraform >= 1.9)
variable "vm_size" {
  type    = string
  default = "Standard_B1s"

  validation {
    condition     = var.environment == "prod" || startswith(var.vm_size, "Standard_B")
    error_message = "Non-prod environments may only use cheap B-series sizes (Standard_B...)."
  }
}

output "accepted" {
  value = "${var.owner_initials}: ${var.environment}, ${var.vm_size}, ${var.disk_gb} GB"
}

# TRY THIS: each command fails with YOUR message
#   terraform plan -var="environment=uat"
#   terraform plan -var="owner_initials=DG"
#   terraform plan -var="disk_gb=10"
#   terraform plan -var="disk_gb=5000"
#   terraform plan -var='admin_cidrs=["10.0.0.0/16","not-a-cidr"]'
#   terraform plan -var="vm_size=Standard_D4s_v5"                         → fails (dev)
#   terraform plan -var="vm_size=Standard_D4s_v5" -var="environment=prod" → allowed
