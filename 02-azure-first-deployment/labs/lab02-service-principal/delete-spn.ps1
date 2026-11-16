# Removes the Lab 2.2 service principal. Role assignments first (otherwise they stay behind as
# "Identity not found"), then the app registration (which also deletes the service principal).
# Usage:  .\delete-spn.ps1 -Student dg
param([Parameter(Mandatory)] [string] $Student)

$appId = az ad sp list --display-name "sp-tf-training-$Student" --query "[0].appId" -o tsv
if (-not $appId) { Write-Host "No service principal named sp-tf-training-$Student found."; exit 0 }

az role assignment delete --assignee $appId --yes 2>$null
az ad app delete --id $appId
Write-Host "Deleted sp-tf-training-$Student ($appId) and its role assignments."
Write-Host 'Also clear the variables in this terminal: Remove-Item Env:ARM_CLIENT_ID, Env:ARM_CLIENT_SECRET, Env:ARM_TENANT_ID'
