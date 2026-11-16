variable "name" {
  type        = string
  description = "Globally unique storage account name (3-24 lowercase letters/digits)."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the storage account."
}

variable "replication_type" {
  type        = string
  description = "LRS, ZRS, GRS, RAGRS, GZRS or RAGZRS."
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "Invalid replication_type."
  }
}

variable "containers" {
  type        = list(string)
  description = "Private blob containers to create."
  default     = []
}

variable "soft_delete_days" {
  type        = number
  description = "Blob and container soft-delete retention."
  default     = 7
}

variable "shared_access_key_enabled" {
  type        = bool
  description = "Allow access keys / SAS. Set false to force Entra ID auth."
  default     = true
}

variable "allowed_subnet_ids" {
  type        = list(string)
  description = "Subnets allowed through the storage firewall."
  default     = []
}

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "Public IPs/CIDRs allowed through the storage firewall (no /31 or /32)."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the storage account."
  default     = {}
}
