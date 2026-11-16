# Cleaned-up version of what `terraform plan -generate-config-out=generated.tf` produces.
terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "legacy" {
  name     = "rg-dg-legacy"
  location = "centralindia"
  tags = {
    course = "tf-azure-training"
    owner  = "dg"
  }
}

resource "azurerm_virtual_network" "legacy" {
  name                = "vnet-legacy"
  location            = azurerm_resource_group.legacy.location
  resource_group_name = azurerm_resource_group.legacy.name
  address_space       = ["10.50.0.0/16"]
  # The inline "subnet" block from the generated code is removed:
  # the subnet is managed by azurerm_subnet.default below.
}

resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.legacy.name
  virtual_network_name = azurerm_virtual_network.legacy.name
  address_prefixes     = ["10.50.1.0/24"]
}

# The rule was created together with the NSG, so it is kept inline here.
resource "azurerm_network_security_group" "legacy" {
  name                = "nsg-legacy"
  location            = azurerm_resource_group.legacy.location
  resource_group_name = azurerm_resource_group.legacy.name

  security_rule {
    name                       = "allow-https"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
