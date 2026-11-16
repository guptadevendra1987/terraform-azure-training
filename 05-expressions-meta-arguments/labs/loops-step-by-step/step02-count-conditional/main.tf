# STEP 2: count as an ON/OFF SWITCH. This is the most common real-world use of count.
#
#   count = condition ? 1 : 0     → "create it only if..."
#
# Production examples: a Bastion host only in prod, a DDoS plan only when compliance requires it,
# backup vaults only for environments that hold data.

terraform {
  required_version = ">= 1.9"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "enable_bastion" {
  type    = bool
  default = false
}

# Switch 1: driven by a boolean variable
resource "terraform_data" "bastion" {
  count = var.enable_bastion ? 1 : 0

  input = { name = "bas-hub-${var.environment}" }
}

# Switch 2: driven by an expression (prod only)
resource "terraform_data" "backup_vault" {
  count = var.environment == "prod" ? 1 : 0

  input = { name = "rsv-backup-${var.environment}" }
}

# Referencing a resource that MAY NOT EXIST:
#   terraform_data.bastion[0].output   → ERROR when count = 0 (index out of range)
#   one(terraform_data.bastion[*].output) → null when count = 0. Safe.
output "bastion" {
  value = one(terraform_data.bastion[*].output.name)
}

output "backup_vault" {
  value = try(terraform_data.backup_vault[0].output.name, "not deployed in ${var.environment}")
}

# TRY THIS
# terraform apply -auto-approve                                     → nothing created, outputs null / "not deployed"
# terraform apply -auto-approve -var="enable_bastion=true"          → bastion created
# terraform apply -auto-approve -var="environment=prod"             → bastion DESTROYED (flag back to false), vault created
