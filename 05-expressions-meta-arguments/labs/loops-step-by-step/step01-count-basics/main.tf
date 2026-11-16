# STEP 1: count basics. "Make N copies of this resource."
#
# Analogy: count is a PHOTOCOPIER. You ask for 3 copies, you get pages 0, 1, 2.
# Each copy is identified only by its POSITION (index), not by a name.
#
# Run:  terraform init && terraform apply -auto-approve
# terraform_data is built into Terraform, so this step needs no cloud account and no provider download.

terraform {
  required_version = ">= 1.9"
}

variable "server_count" {
  type    = number
  default = 3
}

# One block of code becomes 3 resources: web[0], web[1], web[2]
resource "terraform_data" "web" {
  count = var.server_count

  # count.index is 0, 1, 2... Use it to make each copy different
  input = {
    name = "vm-web-${count.index + 1}" # +1 because humans count from 1
    zone = (count.index % 3) + 1       # spread over availability zones 1, 2, 3
  }
}

# [*] is the "splat" operator: "give me this attribute from EVERY copy"
output "all_names" {
  value = terraform_data.web[*].output.name
}

# A single copy is addressed by its index
output "first_server" {
  value = terraform_data.web[0].output
}

output "how_many" {
  value = length(terraform_data.web)
}

# TRY THIS
# 1. terraform state list                   → terraform_data.web[0] ... web[2]
# 2. terraform apply -var="server_count=5"   → 2 to add
# 3. terraform apply -var="server_count=2"   → web[2..4] destroyed (always the LAST ones)
# 4. terraform console → terraform_data.web[1].output.zone
