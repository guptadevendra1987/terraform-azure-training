# STEP 5: the SIX ways to give a variable a value, and who WINS.
#
# Each variable below is set in a different number of places.
# One run prints the whole precedence table. Lowest → highest priority:
#
#   1. default in the variable block
#   2. environment variable  TF_VAR_<name>
#   3. terraform.tfvars                      (loaded automatically)
#   4. *.auto.tfvars                         (loaded automatically, alphabetical order)
#   5. -var-file=<file>   and   -var="name=value"   on the command line (the LAST one wins)
#
# Run it EXACTLY like this (it sets an environment variable just for this command):
#   bash/zsh:   TF_VAR_f=from-TF_VAR TF_VAR_g=from-TF_VAR terraform apply -auto-approve -var-file=extra.tfvars -var="e=from -var flag"
#   PowerShell: $env:TF_VAR_f="from-TF_VAR"; $env:TF_VAR_g="from-TF_VAR"; terraform apply -auto-approve -var-file=extra.tfvars -var="e=from -var flag"

terraform {
  required_version = ">= 1.9"
}

#                                     set in: default | TF_VAR | terraform.tfvars | x.auto.tfvars | -var-file | -var
variable "a" { default = "from default" } #  ✔
variable "b" { default = "from default" } #  ✔                  ✔
variable "c" { default = "from default" } #  ✔                  ✔                   ✔
variable "d" { default = "from default" } #  ✔                  ✔                   ✔                ✔
variable "e" { default = "from default" } #  ✔                  ✔                   ✔                ✔          ✔
variable "f" { default = "from default" } #  ✔        ✔
variable "g" { default = "from default" } #  ✔        ✔         ✔

output "precedence_table" {
  value = {
    a = var.a # expect: from default
    b = var.b # expect: from terraform.tfvars
    c = var.c # expect: from team.auto.tfvars
    d = var.d # expect: from extra.tfvars (-var-file)
    e = var.e # expect: from -var flag
    f = var.f # expect: from-TF_VAR
    g = var.g # expect: from terraform.tfvars (a file BEATS an environment variable)
  }
}

# TRY THIS
# 1. Run the command above and compare each value with the "expect" comments.
# 2. Run without -var-file / -var: which values change?
# 3. Add  -var="d=cli"  BEFORE  -var-file=extra.tfvars, then AFTER it. Order on the command line matters.
# PowerShell users: clean up afterwards with  Remove-Item Env:TF_VAR_f, Env:TF_VAR_g
