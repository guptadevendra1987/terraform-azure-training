data "azurerm_client_config" "current" {}

locals {
  sub = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  rg  = "${local.sub}/resourceGroups/rg-dg-legacy"
}

import {
  to = azurerm_resource_group.legacy
  id = local.rg
}

import {
  to = azurerm_virtual_network.legacy
  id = "${local.rg}/providers/Microsoft.Network/virtualNetworks/vnet-legacy"
}

import {
  to = azurerm_subnet.default
  id = "${local.rg}/providers/Microsoft.Network/virtualNetworks/vnet-legacy/subnets/default"
}

import {
  to = azurerm_network_security_group.legacy
  id = "${local.rg}/providers/Microsoft.Network/networkSecurityGroups/nsg-legacy"
}
