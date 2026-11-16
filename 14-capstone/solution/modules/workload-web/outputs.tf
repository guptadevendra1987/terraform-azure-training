output "app_url" {
  value = "https://${azurerm_linux_web_app.this.default_hostname}"
}

output "app_principal_id" {
  value = azurerm_linux_web_app.this.identity[0].principal_id
}

output "storage_account_id" {
  value = azurerm_storage_account.this.id
}

output "private_endpoint_ip" {
  value = azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
}
