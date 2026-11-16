variable "name" {
  type        = string
  description = "Name of the virtual network."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group in which to create the network."
}

variable "address_space" {
  type        = list(string)
  description = "Address space(s) of the VNet."

  validation {
    condition     = length(var.address_space) > 0 && alltrue([for c in var.address_space : can(cidrhost(c, 0))])
    error_message = "address_space must contain at least one valid CIDR."
  }
}

variable "dns_servers" {
  type        = list(string)
  description = "Custom DNS servers. Empty list = Azure-provided DNS."
  default     = []
}

variable "subnets" {
  description = "Subnets keyed by name."
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
    create_nsg        = optional(bool, true)
    nsg_rules = optional(list(object({
      name                   = string
      priority               = number
      direction              = optional(string, "Inbound")
      access                 = optional(string, "Allow")
      protocol               = optional(string, "Tcp")
      destination_port_range = string
      source_address_prefix  = string
    })), [])
  }))
  default = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
