variable "name_suffix" {
  type = string
}

variable "unique_suffix" {
  type        = string
  description = "Random suffix for globally unique names."
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "storage_account_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase letters/digits."
  }
}

variable "app_integration_subnet_id" {
  type        = string
  description = "Subnet delegated to Microsoft.Web/serverFarms."
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "blob_private_dns_zone_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
