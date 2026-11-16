# Lab 2.2: create a least-privilege service principal (SPN) for Terraform.
#   Reader      on the SUBSCRIPTION     → Terraform can read and check resource providers
#   Contributor on the LAB RESOURCE GROUP only → Terraform can create/change/delete inside it
#
# Who can run this? You need BOTH:
#   1. Permission to create app registrations in Entra ID (allowed for normal users by default,
#      otherwise the "Application Developer" Entra role)
#   2. Owner, User Access Administrator or Role Based Access Control Administrator on the subscription
#      (to create role assignments)
#
# Usage:  .\create-spn.ps1 -Student dg [-ResourceGroup rg-dg-lab02]
param(
    [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9]{2,6}$')] [string] $Student,
    [string] $ResourceGroup = "rg-$Student-lab02"
)
$ErrorActionPreference = 'Stop'

$subId    = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv
$rgScope  = "/subscriptions/$subId/resourceGroups/$ResourceGroup"

if ((az group exists -n $ResourceGroup) -ne 'true') {
    throw "Resource group $ResourceGroup does not exist. Finish Lab 2.1 steps 1-9 first (do NOT destroy yet)."
}

Write-Host "Creating service principal sp-tf-training-$Student with Contributor on $ResourceGroup ..."
$sp = az ad sp create-for-rbac --name "sp-tf-training-$Student" `
        --role Contributor --scopes $rgScope --years 1 | ConvertFrom-Json

Write-Host "Adding Reader on the subscription ..."
az role assignment create --assignee $sp.appId --role Reader --scope "/subscriptions/$subId" | Out-Null

Write-Host "`nDone. The secret is shown ONCE. Paste these lines into your terminal:`n" -ForegroundColor Green
Write-Host "`$env:ARM_CLIENT_ID       = `"$($sp.appId)`""
Write-Host "`$env:ARM_CLIENT_SECRET   = `"$($sp.password)`""
Write-Host "`$env:ARM_TENANT_ID       = `"$tenantId`""
Write-Host "`$env:ARM_SUBSCRIPTION_ID = `"$subId`""
Write-Host "`nNever commit these values. Clean up afterwards with: .\delete-spn.ps1 -Student $Student" -ForegroundColor Yellow
