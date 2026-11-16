variable "student" {
  type        = string
  description = "Your initials (2-6 lowercase letters/digits). Used in names and tags."

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.student))
    error_message = "student must be 2-6 lowercase letters or digits."
  }
}

variable "workload" {
  type        = string
  description = "Short workload name used in resource names."
  default     = "app"
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region. Non-dev environments must use an Indian region."
  default     = "centralindia"

  # Challenge 2: cross-variable validation (Terraform >= 1.9)
  validation {
    condition     = var.environment == "dev" || contains(["centralindia", "southindia", "westindia"], var.location)
    error_message = "test/prod must be deployed to centralindia, southindia or westindia."
  }
}

variable "storage" {
  description = "Storage account settings."
  type = object({
    tier             = optional(string, "Standard")
    replication_type = optional(string, "LRS")
    containers       = optional(list(string), ["data"])
    retention_days   = optional(number, 7)
  })
  default = {}

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.storage.replication_type)
    error_message = "storage.replication_type is not a valid Azure replication type."
  }

  validation {
    condition     = var.storage.retention_days >= 1 && var.storage.retention_days <= 365
    error_message = "storage.retention_days must be between 1 and 365."
  }
}

# Challenge 1
variable "allowed_ip_ranges" {
  type        = list(string)
  description = "Public CIDR ranges allowed to reach the storage account. Empty list = allow all."
  default     = []

  validation {
    condition     = alltrue([for ip in var.allowed_ip_ranges : can(cidrhost(ip, 0))])
    error_message = "Every entry in allowed_ip_ranges must be a valid CIDR, e.g. 203.0.113.0/24."
  }
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged onto every resource."
  default     = {}
}
