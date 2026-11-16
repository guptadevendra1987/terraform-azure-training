#!/usr/bin/env bash
# Creates the Azure Storage account used as the Terraform remote state backend (Module 06 onward).
# Usage: ./bootstrap-backend.sh <student-initials> [location]
set -euo pipefail

STUDENT="${1:?usage: $0 <student-initials> [location]}"
LOCATION="${2:-centralindia}"
[[ "$STUDENT" =~ ^[a-z0-9]{2,6}$ ]] || { echo "student must be 2-6 lowercase letters/digits"; exit 1; }

RG="rg-${STUDENT}-tfstate"
SA="st${STUDENT}tfstate$(tr -dc 'a-z0-9' </dev/urandom | head -c 5)"
CONTAINER="tfstate"
ME=$(az ad signed-in-user show --query id -o tsv)

az group create -n "$RG" -l "$LOCATION" --tags course=tf-azure-training owner="$STUDENT" purpose=tfstate >/dev/null

az storage account create -n "$SA" -g "$RG" -l "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false \
  --tags course=tf-azure-training owner="$STUDENT" >/dev/null

# Versioning + soft delete protect state files from accidental overwrite/deletion
az storage account blob-service-properties update -n "$SA" -g "$RG" \
  --enable-versioning true --enable-delete-retention true --delete-retention-days 7 >/dev/null

# Shared keys are disabled, so grant yourself data-plane RBAC
SA_ID=$(az storage account show -n "$SA" -g "$RG" --query id -o tsv)
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Storage Blob Data Contributor" --scope "$SA_ID" >/dev/null

echo "Waiting 60s for the role assignment to propagate..."
sleep 60
az storage container create -n "$CONTAINER" --account-name "$SA" --auth-mode login >/dev/null

cat <<EOF

Backend ready. Use this in your backend block / backend config file:

resource_group_name  = "$RG"
storage_account_name = "$SA"
container_name       = "$CONTAINER"
use_azuread_auth     = true
EOF
