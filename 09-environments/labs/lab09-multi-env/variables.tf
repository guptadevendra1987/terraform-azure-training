variable "student" {
  type = string
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "location" {
  type = string
}

variable "address_space" {
  type = string
}

variable "subnets" {
  type = map(object({
    netnum = number
  }))
}

variable "enable_delete_lock" {
  type        = bool
  description = "Protect the resource group with a CanNotDelete lock."
  default     = false
}
