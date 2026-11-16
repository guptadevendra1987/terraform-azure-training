output "subnet_ids" {
  value = { for k, s in azurerm_subnet.this : k => s.id }
}

output "subnet_cidrs" {
  value = { for k, s in azurerm_subnet.this : k => one(s.address_prefixes) }
}

output "nat_public_ip" {
  value = one(azurerm_public_ip.nat[*].ip_address) # null when disabled
}

output "all_nsg_rules" {
  value = flatten([
    for subnet, cfg in var.subnets : [
      for r in cfg.nsg_rules : "${subnet}/${r.name}:${r.destination_port_range}"
    ]
  ])
}
