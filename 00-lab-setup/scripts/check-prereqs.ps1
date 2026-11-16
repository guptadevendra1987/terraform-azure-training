# Verifies the tools and Azure login required for the Terraform on Azure course.
$ErrorActionPreference = 'SilentlyContinue'
$failed = $false

function Write-Status($level, $msg) {
    $color = @{ OK = 'Green'; WARN = 'Yellow'; FAIL = 'Red' }[$level]
    Write-Host ("[{0}]" -f $level).PadRight(7) -ForegroundColor $color -NoNewline
    Write-Host $msg
}

function Test-Tool($name, $versionCmd, $required) {
    if (Get-Command $name -ErrorAction SilentlyContinue) {
        $v = (Invoke-Expression $versionCmd | Select-Object -First 1)
        Write-Status 'OK' ("{0,-11} {1}" -f $name, $v)
    }
    elseif ($required) {
        Write-Status 'FAIL' "$name not found"
        $script:failed = $true
    }
    else {
        Write-Status 'WARN' "$name not found (optional, used on Days 4-5)"
    }
}

Test-Tool 'terraform'  "(terraform version -json | ConvertFrom-Json).terraform_version" $true
Test-Tool 'az'         "(az version | ConvertFrom-Json).'azure-cli'" $true
Test-Tool 'git'        "(git --version) -replace 'git version ',''" $true
Test-Tool 'tflint'     "tflint --version" $false
Test-Tool 'checkov'    "checkov --version" $false
Test-Tool 'aztfexport' "aztfexport --version" $false

$account = az account show 2>$null | ConvertFrom-Json
if ($account) {
    Write-Status 'OK' "Azure login: $($account.name) ($($account.id))"
}
else {
    Write-Status 'FAIL' "Not logged in to Azure. Run: az login"
    $failed = $true
}

if ($env:ARM_SUBSCRIPTION_ID) {
    Write-Status 'OK' "ARM_SUBSCRIPTION_ID is set"
}
else {
    Write-Status 'WARN' 'ARM_SUBSCRIPTION_ID not set. Run: $env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)'
}

if ($failed) { Write-Host "`nSetup incomplete - fix the FAIL items above." -ForegroundColor Red; exit 1 }
Write-Host "`nYou are ready for the course!" -ForegroundColor Green
