output "id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map of subnet name => subnet ID."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "nsg_ids" {
  description = "Map of subnet name => NSG ID (only subnets with create_nsg = true)."
  value       = { for k, n in azurerm_network_security_group.this : k => n.id }
}
