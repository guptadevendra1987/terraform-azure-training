# Deletes resource groups created during the course (tag course=tf-azure-training).
# Usage: .\cleanup.ps1 [-Student dg] [-IncludeState] [-Force]
#   -Student       only delete groups with tag owner=<Student>
#   -IncludeState  also delete the remote-state resource group (purpose=tfstate)
param(
    [string] $Student,
    [switch] $IncludeState,
    [switch] $Force
)

$query = "[?tags.course=='tf-azure-training']"
$groups = az group list --query $query | ConvertFrom-Json
if ($Student)       { $groups = $groups | Where-Object { $_.tags.owner -eq $Student } }
if (-not $IncludeState) { $groups = $groups | Where-Object { $_.tags.purpose -ne 'tfstate' } }

if (-not $groups) { Write-Host 'Nothing to clean up.'; exit 0 }

Write-Host 'The following resource groups will be DELETED:' -ForegroundColor Yellow
$groups | ForEach-Object { Write-Host "  - $($_.name) (owner=$($_.tags.owner))" }

if (-not $Force) {
    $answer = Read-Host "Type 'yes' to continue"
    if ($answer -ne 'yes') { Write-Host 'Aborted.'; exit 1 }
}

foreach ($g in $groups) {
    az group delete -n $g.name --yes --no-wait
    Write-Host "Deletion started: $($g.name)"
}
Write-Host "`nDeletions run in the background. Check with: az group list -o table"
