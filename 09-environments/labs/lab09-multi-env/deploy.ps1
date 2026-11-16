# Usage: .\deploy.ps1 -Env dev -Action plan|apply|destroy
param(
    [Parameter(Mandatory)] [ValidateSet('dev', 'prod')] [string] $Env,
    [ValidateSet('plan', 'apply', 'destroy')] [string] $Action = 'plan'
)
$ErrorActionPreference = 'Stop'
$dir = "env/$Env"

# -reconfigure: switching environments means switching backends
terraform init -reconfigure -input=false "-backend-config=$dir/backend.hcl"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

switch ($Action) {
    'plan'    { terraform plan -input=false "-var-file=$dir/terraform.tfvars" "-out=$Env.tfplan" }
    'apply'   { terraform apply -input=false "$Env.tfplan" }
    'destroy' { terraform destroy "-var-file=$dir/terraform.tfvars" }
}
exit $LASTEXITCODE
