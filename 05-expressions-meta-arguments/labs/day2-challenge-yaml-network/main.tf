variable "student" {
  type = string
}

variable "location" {
  type    = string
  default = "centralindia"
}

locals {
  tags  = { course = "tf-azure-training", owner = var.student }
  vnets = yamldecode(file("${path.module}/network.yaml")).vnets

  # Flatten vnet -> subnets into one map keyed "vnet/subnet".
  # Normalise every entry to the same shape so the map has a single element type.
  subnets = merge([
    for vnet_key, vnet in local.vnets : {
      for subnet_key, subnet in vnet.subnets : "${vnet_key}/${subnet_key}" => {
        vnet = vnet_key
        name = subnet_key
        cidr = subnet.cidr
        rules = [
          for r in try(subnet.rules, []) : {
            name     = r.name
            priority = tonumber(r.priority)
            port     = tostring(r.port)
            source   = r.source
          }
        ]
      }
    }
  ]...)

  # NSGs only where rules exist, and never on AzureFirewallSubnet
  nsg_subnets = {
    for k, s in local.subnets : k => s
    if length(s.rules) > 0 && s.name != "AzureFirewallSubnet"
  }

  spokes = { for k, v in local.vnets : k => v if k != "hub" }
}

resource "azurerm_resource_group" "net" {
  name     = "rg-${var.student}-day2"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  for_each = local.vnets

  name                = "vnet-${var.student}-${each.key}"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  address_space       = [each.value.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.this[each.value.vnet].name
  address_prefixes     = [each.value.cidr]
}

resource "azurerm_network_security_group" "this" {
  for_each = local.nsg_subnets

  name                = "nsg-${var.student}-${each.value.vnet}-${each.value.name}"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  tags                = local.tags

  dynamic "security_rule" {
    for_each = each.value.rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = security_rule.value.source
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.nsg_subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = local.spokes

  name                      = "peer-hub-to-${each.key}"
  resource_group_name       = azurerm_resource_group.net.name
  virtual_network_name      = azurerm_virtual_network.this["hub"].name
  remote_virtual_network_id = azurerm_virtual_network.this[each.key].id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = local.spokes

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = azurerm_resource_group.net.name
  virtual_network_name      = azurerm_virtual_network.this[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.this["hub"].id
  allow_forwarded_traffic   = true
}

output "subnet_cidrs" {
  value = { for k, s in local.subnets : k => s.cidr }
}

output "nsg_subnets" {
  value = keys(local.nsg_subnets)
}
