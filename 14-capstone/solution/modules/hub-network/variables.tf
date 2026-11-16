variable "name_suffix" {
  type        = string
  description = "Suffix used in resource names, e.g. dg-dev."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for hub resources."
}

variable "address_space" {
  type        = string
  description = "Hub VNet CIDR (/16 recommended; subnets are carved with cidrsubnet)."

  validation {
    condition     = can(cidrhost(var.address_space, 0)) && tonumber(split("/", var.address_space)[1]) <= 16
    error_message = "address_space must be a valid CIDR of /16 or larger."
  }
}

variable "enable_firewall" {
  type        = bool
  description = "Deploy Azure Firewall Basic (costs money while running)."
  default     = false
}

variable "private_dns_zones" {
  type        = list(string)
  description = "Private DNS zones hosted in the hub and linked to spokes."
  default     = ["privatelink.blob.core.windows.net"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
