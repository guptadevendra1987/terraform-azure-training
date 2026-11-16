variable "name_suffix" {
  type        = string
  description = "Suffix used in resource names, e.g. dg-dev."
}

variable "spoke_name" {
  type        = string
  description = "Short spoke name, e.g. web or data."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the spoke."
}

variable "address_space" {
  type        = string
  description = "Spoke VNet CIDR (/16)."
}

variable "subnets" {
  description = "Subnets keyed by name; netnum is the /24 index inside the /16."
  type = map(object({
    netnum     = number
    delegation = optional(string)
    nsg_rules = optional(list(object({
      name     = string
      priority = number
      port     = string
      source   = string
    })), [])
  }))
}

variable "hub" {
  description = "Hub details from the hub-network module."
  type = object({
    vnet_id                = string
    vnet_name              = string
    resource_group_name    = string
    firewall_enabled       = optional(bool, false)
    firewall_private_ip    = optional(string)
    private_dns_zone_names = optional(list(string), [])
  })
}

variable "tags" {
  type    = map(string)
  default = {}
}
