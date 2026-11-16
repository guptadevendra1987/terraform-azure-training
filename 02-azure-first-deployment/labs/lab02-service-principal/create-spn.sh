#!/usr/bin/env bash
# Lab 2.2: create a least-privilege service principal (SPN) for Terraform.
#   Reader      on the SUBSCRIPTION            → Terraform can read and check resource providers
#   Contributor on the LAB RESOURCE GROUP only  → Terraform can create/change/delete inside it
#
# Who can run this? You need BOTH:
#   1. Permission to create app registrations in Entra ID (allowed for normal users by default,
#      otherwise the "Application Developer" Entra role)
#   2. Owner, User Access Administrator or Role Based Access Control Administrator on the subscription
#
# Usage:  ./create-spn.sh <student> [resource-group]
set -euo pipefail
STUDENT="${1:?usage: $0 <student> [resource-group]}"
RG="${2:-rg-${STUDENT}-lab02}"

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

if [ "$(az group exists -n "$RG")" != "true" ]; then
  echo "Resource group $RG does not exist. Finish Lab 2.1 steps 1-9 first (do NOT destroy yet)."; exit 1
fi

echo "Creating service principal sp-tf-training-$STUDENT with Contributor on $RG ..."
SP_JSON=$(az ad sp create-for-rbac --name "sp-tf-training-$STUDENT" \
  --role Contributor --scopes "/subscriptions/$SUB_ID/resourceGroups/$RG" --years 1)
APP_ID=$(echo "$SP_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['appId'])")
SECRET=$(echo "$SP_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['password'])")

echo "Adding Reader on the subscription ..."
az role assignment create --assignee "$APP_ID" --role Reader --scope "/subscriptions/$SUB_ID" >/dev/null

cat <<EOF

Done. The secret is shown ONCE. Paste these lines into your terminal:

export ARM_CLIENT_ID="$APP_ID"
export ARM_CLIENT_SECRET="$SECRET"
export ARM_TENANT_ID="$TENANT_ID"
export ARM_SUBSCRIPTION_ID="$SUB_ID"

Never commit these values. Clean up afterwards with: ./delete-spn.sh $STUDENT
EOF
