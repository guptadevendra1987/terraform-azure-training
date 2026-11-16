variable "student" { type = string }

variable "location" {
  type    = string
  default = "centralindia"
}

variable "address_space" {
  type    = string
  default = "10.20.0.0/16"
}

variable "enable_nat_gateway" {
  type    = bool
  default = false
}

variable "subnets" {
  description = "Subnets keyed by name. newbits/netnum feed cidrsubnet()."
  type = map(object({
    newbits           = optional(number, 8)
    netnum            = number
    service_endpoints = optional(list(string), [])
    nat_gateway       = optional(bool, false)
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

  default = {
    web = {
      netnum = 1
      nsg_rules = [
        { name = "allow-https", priority = 100, destination_port_range = "443", source_address_prefix = "Internet" },
        { name = "allow-http", priority = 110, destination_port_range = "80", source_address_prefix = "Internet" },
      ]
    }
    app = {
      netnum      = 2
      nat_gateway = true
      nsg_rules = [
        { name = "allow-web", priority = 100, destination_port_range = "8080", source_address_prefix = "10.20.1.0/24" },
      ]
    }
    data = {
      netnum            = 3
      service_endpoints = ["Microsoft.Sql", "Microsoft.Storage"]
      nsg_rules = [
        { name = "allow-app-sql", priority = 100, destination_port_range = "1433", source_address_prefix = "10.20.2.0/24" },
      ]
    }
  }

  validation {
    condition     = alltrue(flatten([for s in var.subnets : [for r in s.nsg_rules : r.priority >= 100 && r.priority <= 4096]]))
    error_message = "NSG rule priorities must be between 100 and 4096."
  }
}
