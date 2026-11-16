# STEP 7: outputs and sensitive values.
#
# Outputs are the RESULTS your configuration hands back:
#   - shown after apply, for humans
#   - read by scripts and pipelines:  terraform output -raw / -json
#   - the "return values" of a module (Module 07): module.network.subnet_ids
#
# sensitive = true HIDES a value on the screen. It does NOT encrypt it: it is still in the state file.

terraform {
  required_version = ">= 1.9"
}

variable "db_admin_password" {
  type        = string
  description = "Database admin password."
  sensitive   = true                  # hidden in plan/apply output
  default     = "Training-Only-P@ss1" # NEVER put a real password in code. This is a demo
}

resource "terraform_data" "database" {
  input = {
    server   = "sql-payments-dev"
    port     = 1433
    password = var.db_admin_password
  }
}

# A simple string
output "db_server" {
  description = "Database server name."
  value       = terraform_data.database.output.server
}

# An object: outputs can be any type
output "db_connection_info" {
  description = "Everything an app needs to connect, except the password."
  value = {
    server = terraform_data.database.output.server
    port   = terraform_data.database.output.port
  }
}

# A sensitive output: REQUIRED here, because the value comes from a sensitive variable.
# Remove "sensitive = true" and plan: Terraform refuses ("Output refers to sensitive values").
output "db_password" {
  description = "Admin password (sensitive)."
  value       = var.db_admin_password
  sensitive   = true
}

# TRY THIS
# 1. terraform apply -auto-approve
#      → db_password = <sensitive>. The plan also shows (sensitive value) for the resource input.
# 2. terraform output                       → all outputs, password still hidden
# 3. terraform output db_server             → "sql-payments-dev"   (with quotes)
# 4. terraform output -raw db_server        → sql-payments-dev     (no quotes: use this in scripts)
# 5. terraform output -json db_connection_info
# 6. terraform output -raw db_password      → the REAL password. Asking explicitly reveals it!
# 7. THE IMPORTANT ONE: look inside the state file
#      bash:        grep -c "Training-Only-P@ss1" terraform.tfstate
#      PowerShell:  Select-String "Training-Only-P@ss1" terraform.tfstate
#    → found, in plain text. Sensitive ≠ secret. Protect state (Module 06) or avoid storing secrets (Modules 10 and 13).
