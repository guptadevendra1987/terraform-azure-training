#!/usr/bin/env bash
# Usage: ./deploy.sh <dev|prod> <plan|apply|destroy>
set -euo pipefail
ENV="${1:?environment}"; ACTION="${2:-plan}"
DIR="env/$ENV"
[ -d "$DIR" ] || { echo "Unknown environment: $ENV"; exit 1; }

# -reconfigure: switching environments means switching backends
terraform init -reconfigure -input=false -backend-config="$DIR/backend.hcl"

case "$ACTION" in
  plan)    terraform plan -input=false -var-file="$DIR/terraform.tfvars" -out="$ENV.tfplan" ;;
  apply)   terraform apply -input=false "$ENV.tfplan" ;;
  destroy) terraform destroy -var-file="$DIR/terraform.tfvars" ;;
  *) echo "Unknown action: $ACTION"; exit 1 ;;
esac
