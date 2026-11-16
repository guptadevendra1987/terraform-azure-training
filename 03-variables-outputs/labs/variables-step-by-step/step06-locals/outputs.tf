output "names" {
  value = [
    terraform_data.resource_group.output.name,
    terraform_data.key_vault.output.name,
    terraform_data.app_service.output.name,
  ]
}

output "app_service_sku" {
  value = terraform_data.app_service.output.sku
}

output "tags" {
  value = local.tags
}

# TRY THIS
# 1. terraform apply -auto-approve                          → names start with payments-api-dev
# 2. terraform apply -auto-approve -var="environment=prod"  → ALL names and the SKU change together
# 3. terraform plan -var="name_prefix=hacked"
#      → ERROR: Value for undeclared variable. Locals can't be set from outside.
# 4. terraform plan -var='extra_tags={managed_by="manual"}'
#      → managed_by stays "terraform": the company tags were merged last
# 5. terraform console  →  local.app_slug   local.tags
