# STEP 6: locals. Also the STANDARD FILE LAYOUT.
# From this step on the code is split the way real projects do it:
#   variables.tf → inputs     locals.tf → calculations     main.tf → resources     outputs.tf → results
# Terraform reads ALL .tf files in the folder as one configuration. The file names are only for humans.

variable "app_name" {
  type        = string
  description = "Application name, e.g. Payments API."
  default     = "Payments API"
}

variable "environment" {
  type        = string
  description = "dev, test or prod."
  default     = "dev"
}

variable "extra_tags" {
  type        = map(string)
  description = "Extra tags the team wants to add."
  default     = { project = "checkout" }
}
