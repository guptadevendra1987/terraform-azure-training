#!/usr/bin/env bash
# Removes the Lab 2.2 service principal. Role assignments first (otherwise they stay behind as
# "Identity not found"), then the app registration (which also deletes the service principal).
# Usage:  ./delete-spn.sh <student>
set -euo pipefail
STUDENT="${1:?usage: $0 <student>}"

APP_ID=$(az ad sp list --display-name "sp-tf-training-$STUDENT" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then echo "No service principal named sp-tf-training-$STUDENT found."; exit 0; fi

az role assignment delete --assignee "$APP_ID" --yes 2>/dev/null || true
az ad app delete --id "$APP_ID"
echo "Deleted sp-tf-training-$STUDENT ($APP_ID) and its role assignments."
echo "Also clear the variables in this terminal: unset ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID"
