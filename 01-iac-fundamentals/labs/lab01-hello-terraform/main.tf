terraform {
  required_version = ">= 1.9"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_pet" "server" {
  length    = 2
  separator = "-"
}

resource "local_file" "welcome" {
  filename = "${path.module}/output/welcome.txt"
  content  = <<-EOT
    Hello from Terraform!
    Your server name is: ${random_pet.server.id}
    Terraform workspace: ${terraform.workspace}
  EOT
}

# Challenge solution
resource "random_password" "db" {
  length  = 16
  special = true
}

output "server_name" {
  value = random_pet.server.id
}

output "file_path" {
  value = local_file.welcome.filename
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
