variable "student" {
  type        = string
  description = "Your initials."

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.student))
    error_message = "student must be 2-6 lowercase letters or digits."
  }
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "hub_address_space" {
  type = string
}

variable "enable_firewall" {
  type    = bool
  default = false
}

variable "spokes" {
  description = "Spoke networks keyed by name. The 'web' spoke hosts the workload."
  type = map(object({
    address_space = string
    subnets = map(object({
      netnum     = number
      delegation = optional(string)
      nsg_rules = optional(list(object({
        name     = string
        priority = number
        port     = string
        source   = string
      })), [])
    }))
  }))

  validation {
    condition     = contains(keys(var.spokes), "web")
    error_message = "A spoke named 'web' is required (it hosts the workload)."
  }

  validation {
    condition = alltrue([
      for s in values(var.spokes) : contains(keys(s.subnets), "app") && contains(keys(s.subnets), "pe")
    ])
    error_message = "Every spoke needs an 'app' subnet and a 'pe' (private endpoint) subnet."
  }
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}
