output "vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Next hop for spoke route tables; null when the firewall is disabled."
  value       = one(azurerm_firewall.hub[*].ip_configuration[0].private_ip_address)
}

output "private_dns_zone_ids" {
  description = "Map of zone name => zone ID."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}

output "private_dns_zone_names" {
  value = keys(azurerm_private_dns_zone.this)
}
