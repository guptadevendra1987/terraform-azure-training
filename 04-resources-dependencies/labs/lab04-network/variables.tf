variable "student" {
  type        = string
  description = "Your initials."
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "address_space" {
  type    = string
  default = "10.10.0.0/16"
}

variable "admin_source_ip" {
  type        = string
  description = "Your public IP for SSH (find it: curl ifconfig.me)."
}
