output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.main.name
}

output "storage_account" {
  description = "Storage account details."
  value = {
    name     = azurerm_storage_account.main.name
    id       = azurerm_storage_account.main.id
    endpoint = azurerm_storage_account.main.primary_blob_endpoint
  }
}

output "storage_primary_key" {
  description = "Primary access key (sensitive)."
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

# Challenge 3
output "portal_url" {
  description = "Direct link to the resource group in the Azure Portal."
  value       = "https://portal.azure.com/#@/resource${azurerm_resource_group.main.id}"
}
