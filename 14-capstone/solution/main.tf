locals {
  name_suffix = "${var.student}-${var.environment}"
  tags = merge(var.extra_tags, {
    course      = "tf-azure-training"
    owner       = var.student
    environment = var.environment
    managed_by  = "terraform"
    project     = "capstone"
  })
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

# --- Resource groups: one per responsibility -------------------------------

resource "azurerm_resource_group" "this" {
  for_each = toset(concat(["hub", "shared"], keys(var.spokes)))

  name     = "rg-${local.name_suffix}-${each.key}"
  location = var.location
  tags     = local.tags
}

# Production hub is protected against accidental deletion outside Terraform
resource "azurerm_management_lock" "hub" {
  count = var.environment == "prod" ? 1 : 0

  name       = "lock-hub"
  scope      = azurerm_resource_group.this["hub"].id
  lock_level = "CanNotDelete"
}

# --- Shared services ----------------------------------------------------------

resource "azurerm_log_analytics_workspace" "shared" {
  name                = "log-${local.name_suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this["shared"].name
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "prod" ? 90 : 30
  tags                = local.tags
}

# --- Hub ----------------------------------------------------------------------

module "hub" {
  source = "./modules/hub-network"

  name_suffix         = local.name_suffix
  location            = var.location
  resource_group_name = azurerm_resource_group.this["hub"].name
  address_space       = var.hub_address_space
  enable_firewall     = var.enable_firewall
  tags                = local.tags
}

# --- Spokes -------------------------------------------------------------------

module "spoke" {
  source   = "./modules/spoke-network"
  for_each = var.spokes

  name_suffix         = local.name_suffix
  spoke_name          = each.key
  location            = var.location
  resource_group_name = azurerm_resource_group.this[each.key].name
  address_space       = each.value.address_space
  subnets             = each.value.subnets
  tags                = local.tags

  hub = {
    vnet_id                = module.hub.vnet_id
    vnet_name              = module.hub.vnet_name
    resource_group_name    = azurerm_resource_group.this["hub"].name
    firewall_enabled       = var.enable_firewall
    firewall_private_ip    = module.hub.firewall_private_ip
    private_dns_zone_names = module.hub.private_dns_zone_names
  }
}

# --- Workload in the web spoke -------------------------------------------------

module "web" {
  source = "./modules/workload-web"

  name_suffix          = "${local.name_suffix}-web"
  unique_suffix        = random_string.suffix.result
  environment          = var.environment
  location             = var.location
  resource_group_name  = azurerm_resource_group.this["web"].name
  storage_account_name = "st${var.student}${var.environment}${random_string.suffix.result}"

  app_integration_subnet_id  = module.spoke["web"].subnet_ids["app"]
  private_endpoint_subnet_id = module.spoke["web"].subnet_ids["pe"]
  blob_private_dns_zone_id   = module.hub.private_dns_zone_ids["privatelink.blob.core.windows.net"]
  log_analytics_workspace_id = azurerm_log_analytics_workspace.shared.id
  tags                       = local.tags
}
