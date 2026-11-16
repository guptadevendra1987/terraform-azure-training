# Creates the Azure Storage account used as the Terraform remote state backend (Module 06 onward).
# Usage: .\bootstrap-backend.ps1 -Student dg [-Location centralindia]
param(
    [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9]{2,6}$')] [string] $Student,
    [string] $Location = 'centralindia'
)
$ErrorActionPreference = 'Stop'

$rg        = "rg-$Student-tfstate"
$suffix    = -join ((48..57) + (97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ })
$sa        = "st${Student}tfstate$suffix"
$container = 'tfstate'
$me        = az ad signed-in-user show --query id -o tsv

az group create -n $rg -l $Location --tags course=tf-azure-training owner=$Student purpose=tfstate | Out-Null

az storage account create -n $sa -g $rg -l $Location `
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 `
    --allow-blob-public-access false --allow-shared-key-access false `
    --tags course=tf-azure-training owner=$Student | Out-Null

# Versioning + soft delete protect state files from accidental overwrite/deletion
az storage account blob-service-properties update -n $sa -g $rg `
    --enable-versioning true --enable-delete-retention true --delete-retention-days 7 | Out-Null

# Shared keys are disabled, so grant yourself data-plane RBAC
$saId = az storage account show -n $sa -g $rg --query id -o tsv
az role assignment create --assignee-object-id $me --assignee-principal-type User `
    --role 'Storage Blob Data Contributor' --scope $saId | Out-Null

Write-Host 'Waiting 60s for the role assignment to propagate...'
Start-Sleep -Seconds 60
az storage container create -n $container --account-name $sa --auth-mode login | Out-Null

Write-Host "`nBackend ready. Use this in your backend block / backend config file:`n" -ForegroundColor Green
@"
resource_group_name  = "$rg"
storage_account_name = "$sa"
container_name       = "$container"
use_azuread_auth     = true
"@
