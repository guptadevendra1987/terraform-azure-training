output "public_ip" {
  value = azurerm_public_ip.vm.ip_address
}

output "website_url" {
  value = "http://${azurerm_public_ip.vm.fqdn}"
}

output "ssh_command" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "vm_principal_id" {
  description = "Object ID of the VM's system-assigned managed identity."
  value       = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}
