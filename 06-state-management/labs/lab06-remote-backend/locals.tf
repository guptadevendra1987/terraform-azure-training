locals {
  # Naming convention: <type>-<student>-<workload>-<env>
  name_suffix = "${var.student}-${var.workload}-${var.environment}"

  # Storage names: no dashes, at most 24 characters
  storage_name = substr(lower("st${var.student}${var.workload}${var.environment}${random_string.suffix.result}"), 0, 24)

  common_tags = merge(var.extra_tags, {
    course      = "tf-azure-training"
    owner       = var.student
    environment = var.environment
    managed_by  = "terraform"
  })

  is_production = var.environment == "prod"
}
