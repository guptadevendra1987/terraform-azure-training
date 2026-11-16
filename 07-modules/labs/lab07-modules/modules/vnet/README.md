# vnet module

Creates a virtual network, its subnets, and an optional NSG per subnet with inline rules.

## Usage

```hcl
module "network" {
  source = "../modules/vnet"

  name                = "vnet-dg-dev"
  location            = "centralindia"
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.30.0.0/16"]

  subnets = {
    web = {
      address_prefixes = ["10.30.1.0/24"]
      nsg_rules = [
        { name = "allow-https", priority = 100, destination_port_range = "443", source_address_prefix = "Internet" }
      ]
    }
    data = {
      address_prefixes  = ["10.30.3.0/24"]
      service_endpoints = ["Microsoft.Storage"]
    }
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | n/a | VNet name |
| `location` | `string` | n/a | Azure region |
| `resource_group_name` | `string` | n/a | Target resource group |
| `address_space` | `list(string)` | n/a | VNet CIDRs |
| `dns_servers` | `list(string)` | `[]` | Custom DNS |
| `subnets` | `map(object)` | `{}` | Subnets, service endpoints, and NSG rules |
| `tags` | `map(string)` | `{}` | Tags |

## Outputs

| Name | Description |
|---|---|
| `id` | VNet ID |
| `name` | VNet name |
| `subnet_ids` | Map of subnet name to ID |
| `nsg_ids` | Map of subnet name to NSG ID |

> Generate this table automatically with `terraform-docs markdown table . > README.md`.
