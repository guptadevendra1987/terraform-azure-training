variable "student" {
  type = string
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "vm_size" {
  type        = string
  description = "VM size. Keep it small for the course."
  default     = "Standard_B2s"

  validation {
    condition     = can(regex("^Standard_B", var.vm_size))
    error_message = "Training labs only allow burstable B-series sizes."
  }
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to your SSH public key (create one with: ssh-keygen -t rsa -b 4096)."
  default     = "~/.ssh/id_rsa.pub"
}

variable "admin_source_ip" {
  type        = string
  description = "Your public IP for SSH."
}
