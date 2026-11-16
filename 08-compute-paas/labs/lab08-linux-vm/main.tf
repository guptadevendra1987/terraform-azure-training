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
  features {
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}

locals {
  name = "${var.student}-web"
  tags = { course = "tf-azure-training", owner = var.student, role = "web" }
}

resource "azurerm_resource_group" "vm" {
  name     = "rg-${var.student}-lab08-vm"
  location = var.location
  tags     = local.tags
}

# --- Network ----------------------------------------------------------------

resource "azurerm_virtual_network" "vm" {
  name                = "vnet-${local.name}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  address_space       = ["10.60.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "vm" {
  name                 = "snet-vm"
  resource_group_name  = azurerm_resource_group.vm.name
  virtual_network_name = azurerm_virtual_network.vm.name
  address_prefixes     = ["10.60.1.0/24"]
}

resource "azurerm_network_security_group" "vm" {
  name                = "nsg-${local.name}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  tags                = local.tags

  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh-admin"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_public_ip" "vm" {
  name                = "pip-${local.name}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.name}-${substr(md5(azurerm_resource_group.vm.id), 0, 6)}"
  tags                = local.tags
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-${local.name}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

# --- Virtual machine --------------------------------------------------------

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "vm-${local.name}"
  computer_name         = "web01"
  location              = azurerm_resource_group.vm.location
  resource_group_name   = azurerm_resource_group.vm.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]
  tags                  = local.tags

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # cloud-init configures the OS on first boot; no provisioners needed
  custom_data = base64encode(templatefile("${path.module}/cloud-init.tftpl", {
    hostname = "web01"
    owner    = var.student
    packages = ["nginx", "jq"]
  }))

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {} # managed storage account

  # Changing custom_data replaces the VM. Ignore it if instances are long-lived and configured by other tools.
  # lifecycle { ignore_changes = [custom_data] }
}

# Auto-shutdown at 19:00 IST to save cost
resource "azurerm_dev_test_global_vm_shutdown_schedule" "vm" {
  virtual_machine_id    = azurerm_linux_virtual_machine.vm.id
  location              = azurerm_resource_group.vm.location
  enabled               = true
  daily_recurrence_time = "1900"
  timezone              = "India Standard Time"

  notification_settings {
    enabled = false
  }
}
