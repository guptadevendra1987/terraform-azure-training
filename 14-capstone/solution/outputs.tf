output "app_url" {
  value = module.web.app_url
}

output "hub_vnet_id" {
  value = module.hub.vnet_id
}

output "spoke_subnet_ids" {
  value = { for k, s in module.spoke : k => s.subnet_ids }
}

output "storage_private_endpoint_ip" {
  value = module.web.private_endpoint_ip
}

output "firewall_private_ip" {
  value = module.hub.firewall_private_ip
}
